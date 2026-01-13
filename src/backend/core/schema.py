import graphene
import graphql_jwt
from django.contrib.auth import get_user_model
from django.db import models as django_models
from graphene import relay
from graphene_django import DjangoObjectType
from graphql import GraphQLError
from graphql_jwt.decorators import login_required
from django.contrib.auth import login
from django.utils import timezone

from apps.errands.models import Errand
from apps.errands.services import store_errand_image
from apps.locations.models import UserLocation
from apps.roles.models import Role
from apps.users.models import UserProfile, FCMToken
from apps.users.services import (
    verify_google_id_token,
    get_or_create_google_user,
    get_access_token,
    get_refresh_token,
)
from apps.escrow.models import Escrow
from apps.escrow.services import handle_errand_status_change
from errand_location.models import ErrandLocation

# Import Flutterwave service
try:
    from apps.payments.flutterwave_service import flutterwave_service
    FLUTTERWAVE_AVAILABLE = True
except ImportError:
    FLUTTERWAVE_AVAILABLE = False
    flutterwave_service = None

User = get_user_model()

# =====================
# GRAPHQL TYPES
# =====================

class RoleType(DjangoObjectType):
    class Meta:
        model = Role
        fields = ("name",)


class ErrandLocationType(DjangoObjectType):
    class Meta:
        model = ErrandLocation
        fields = (
            "id",
            "kind",
            "latitude",
            "longitude",
            "address",
        )


class LocationType(DjangoObjectType):
    label = graphene.String()
    type = graphene.String()
    isActive = graphene.Boolean()

    class Meta:
        model = UserLocation
        fields = (
            "id",
            "latitude",
            "longitude",
            "address",
            "mode",
            "updated_at",
        )

    def resolve_label(self, info):
        return getattr(self, "address", None)

    def resolve_type(self, info):
        return getattr(self, "mode", None)

    def resolve_isActive(self, info):
        # If you later add an is_active field, map it here; for now, treat existing location as active
        return True


# =====================
# USER TYPE FIX
# =====================

class UserType(DjangoObjectType):
    roles = graphene.List(RoleType)
    location = graphene.Field(LocationType, required=False)
    name = graphene.String()
    avatar = graphene.String()
    trust_score = graphene.Int()

    class Meta:
        model = User
        interfaces = (relay.Node,)
        fields = (
            "id",
            "email",
            "is_active",
            "is_staff",
            "roles",
            # expose single location via resolver
        )

    def resolve_roles(self, info):
        profile = getattr(self, "profile", None)
        return profile.roles.all() if profile else []

    def resolve_location(self, info):
        return getattr(self, "location", None)

    def resolve_name(self, info):
        profile = getattr(self, "profile", None)
        pname = getattr(profile, "name", None) if profile else None
        if pname:
            return pname
        first_name = getattr(self, "first_name", "")
        last_name = getattr(self, "last_name", "")
        full = " ".join([n for n in [first_name, last_name] if n]).strip()
        return full or None

    def resolve_avatar(self, info):
        profile = getattr(self, "profile", None)
        return getattr(profile, "avatar", None) if profile else None

    def resolve_trust_score(self, info):
        profile = getattr(self, "profile", None)
        return getattr(profile, "trust_score", None) if profile else None
    
    bank_account = graphene.JSONString()
    
    def resolve_bank_account(self, info):
        """Get user's bank account details (masked for security)"""
        profile = getattr(self, "profile", None)
        if not profile:
            return None
        
        if not all([profile.bank_account_number, profile.bank_code, profile.bank_account_name]):
            return None
        
        # Mask account number for security (show last 4 digits only)
        account_number = profile.bank_account_number
        masked_account = '*' * (len(account_number) - 4) + account_number[-4:] if len(account_number) > 4 else '****'
        
        return {
            'account_number': masked_account,
            'bank_code': profile.bank_code,
            'account_name': profile.bank_account_name,
            'has_account': True
        }

class EscrowType(DjangoObjectType):
    buyer = graphene.Field(UserType)
    runner = graphene.Field(UserType)
    amount = graphene.Decimal()

    class Meta:
        model = Escrow
        interfaces = (relay.Node,)
        fields = (
            "id",
            "errand",
            "buyer",
            "runner",
            "amount",
            "status",
            "created_at",
            "released_at",
            "refunded_at",
            "transaction_id",
        )

    def resolve_buyer(self, info):
        return self.buyer
    
    def resolve_runner(self, info):
        return self.runner


class ErrandType(DjangoObjectType):
    locations = graphene.List(ErrandLocationType)
    runner = graphene.Field(UserType)
    price = graphene.Decimal()
    escrow = graphene.Field(EscrowType)

    class Meta:
        model = Errand
        interfaces = (relay.Node,)
        fields = (
            "id",
            "type",
            "instructions",
            "speed",
            "payment_method",
            "status",
            "created_at",
            "image_url",
            "locations",
            "price",
            "runner",
        )

    def resolve_locations(self, info):
        return self.locations.all()
    
    def resolve_runner(self, info):
        return self.runner
    
    def resolve_escrow(self, info):
        try:
            return self.escrow
        except Escrow.DoesNotExist:
            return None


class SaveErrandDraft(graphene.Mutation):
    errand = graphene.Field(ErrandType)

    class Arguments:
        id = graphene.ID(required=False)
        type = graphene.String(required=False)
        instructions = graphene.String(required=False)
        speed = graphene.String(required=False)
        payment_method = graphene.String(required=False)
        go_to = graphene.JSONString(required=False)
        return_to = graphene.JSONString(required=False)

    @login_required
    def mutate(self, info, **data):
        user = info.context.user
        errand_id = data.get("id")

        if errand_id:
            errand = Errand.objects.get(id=errand_id, user=user)
        else:
            errand = Errand.objects.create(
                user=user,
                status="DRAFT",
            )

        # Update scalar fields
        for field in ["type", "instructions", "speed", "payment_method"]:
            if data.get(field) is not None:
                setattr(errand, field, data[field])

        errand.save()

        # Reset locations (drafts should be replaceable)
        if data.get("go_to") or data.get("return_to"):
            errand.locations.all().delete()

        if data.get("go_to"):
            ErrandLocation.objects.create(
                errand=errand,
                kind="GO_TO",
                **data["go_to"]
            )

        if data.get("return_to"):
            ErrandLocation.objects.create(
                errand=errand,
                kind="RETURN_TO",
                **data["return_to"]
            )

        return SaveErrandDraft(errand=errand)

class IssueSessionTokens(graphene.Mutation):
    access = graphene.String()
    refresh = graphene.String()
    user = graphene.Field(UserType)

    @login_required
    def mutate(self, info):
        user = info.context.user
        access = get_access_token(user)
        refresh = get_refresh_token(user)
        return IssueSessionTokens(access=access, refresh=refresh, user=user)

class VerifyGoogleToken(graphene.Mutation):
    class Arguments:
        id_token = graphene.String(required=True)

    access = graphene.String()
    refresh = graphene.String()
    user = graphene.Field(UserType)

    def mutate(self, info, id_token):
        payload = verify_google_id_token(id_token)
        user = get_or_create_google_user(payload)

        # Establish session (optional but harmless)
        request = info.context
        login(request, user, backend="django.contrib.auth.backends.ModelBackend")

        access = get_access_token(user)
        refresh = get_refresh_token(user)
        return VerifyGoogleToken(access=access, refresh=refresh, user=user)

# =====================
# USER MUTATIONS
# =====================

class UpdateUserLocation(graphene.Mutation):
    class Arguments:
        latitude = graphene.Float(required=True)
        longitude = graphene.Float(required=True)
        is_preferred = graphene.Boolean(default_value=True)

    location = graphene.Field(LocationType, required=False)

    @login_required
    def mutate(self, info, latitude, longitude, is_preferred):
        user = info.context.user

        # Upsert user's current location (UserLocation is OneToOne)
        location, _ = UserLocation.objects.update_or_create(
            user=user,
            defaults={
                "latitude": latitude,
                "longitude": longitude,
            },
        )

        return UpdateUserLocation(location=location)


class BecomeRunner(graphene.Mutation):
    ok = graphene.Boolean()

    @login_required
    def mutate(self, info):
        user = info.context.user
        runner_role = Role.objects.get(name=Role.RUNNER)

        profile = getattr(user, "profile", None)
        if not profile:
            profile = UserProfile.objects.create(user=user)

        if profile.roles.filter(id=runner_role.id).exists():
            return BecomeRunner(ok=True)

        profile.roles.add(runner_role)
        return BecomeRunner(ok=True)


class RegisterFCMToken(graphene.Mutation):
    """Register or update a Firebase Cloud Messaging token for push notifications"""
    class Arguments:
        token = graphene.String(required=True)
        device_id = graphene.String(required=False)

    ok = graphene.Boolean()
    message = graphene.String()

    @login_required
    def mutate(self, info, token, device_id=None):
        user = info.context.user
        
        # Update or create FCM token
        fcm_token, created = FCMToken.objects.update_or_create(
            token=token,
            defaults={
                'user': user,
                'device_id': device_id,
                'is_active': True,
            }
        )
        
        message = "FCM token registered successfully" if created else "FCM token updated successfully"
        return RegisterFCMToken(ok=True, message=message)


class UnregisterFCMToken(graphene.Mutation):
    """Unregister a Firebase Cloud Messaging token"""
    class Arguments:
        token = graphene.String(required=True)

    ok = graphene.Boolean()
    message = graphene.String()

    @login_required
    def mutate(self, info, token):
        user = info.context.user
        
        # Deactivate token (don't delete, in case we need to track it)
        updated = FCMToken.objects.filter(user=user, token=token).update(is_active=False)
        
        if updated:
            return UnregisterFCMToken(ok=True, message="FCM token unregistered successfully")
        else:
            return UnregisterFCMToken(ok=False, message="FCM token not found")

# =====================
# ERRAND MUTATIONS
# =====================

class CreateErrand(graphene.Mutation):
    errand_id = graphene.ID()

    class Arguments:
        type = graphene.String(required=True)
        instructions = graphene.String(required=True)
        speed = graphene.String(required=True)
        payment_method = graphene.String(required=True)
        price = graphene.Decimal(required=False)
        go_to = graphene.JSONString(required=True)
        return_to = graphene.JSONString(required=False)
        image_base64 = graphene.String(required=False)

    @login_required
    def mutate(self, info, **data):
        user = info.context.user

        errand = Errand.objects.create(
            user=user,
            type=data["type"],
            instructions=data["instructions"],
            speed=data["speed"],
            payment_method=data["payment_method"],
            price=data.get("price"),
        )

        # Optional image
        if data.get("image_base64"):
            image_url = store_errand_image(data["image_base64"], user)
            errand.image_url = image_url
            errand.save(update_fields=["image_url"])

        ErrandLocation.objects.create(
            errand=errand,
            kind="GO_TO",
            **data["go_to"]
        )

        if data.get("return_to"):
            ErrandLocation.objects.create(
                errand=errand,
                kind="RETURN_TO",
                **data["return_to"]
            )

        return CreateErrand(errand_id=errand.id)



class UpdateErrand(graphene.Mutation):
    class Arguments:
        id = graphene.ID(required=True)
        title = graphene.String()
        description = graphene.String()
        budget = graphene.Decimal()
        status = graphene.String()
        price = graphene.Decimal()

    errand = graphene.Field(ErrandType)

    @login_required
    def mutate(self, info, id, **updates):
        errand = Errand.objects.get(pk=id)

        if errand.user != info.context.user:
            raise GraphQLError("Not permitted")

        old_status = errand.status
        for field, value in updates.items():
            if value is not None:
                setattr(errand, field, value)

        errand.save()
        
        # Handle escrow logic when status changes
        if 'status' in updates and updates['status'] != old_status:
            try:
                handle_errand_status_change(
                    errand=errand,
                    old_status=old_status,
                    new_status=errand.status,
                    runner=errand.runner
                )
            except Exception as e:
                # Log error but don't fail the mutation
                import logging
                logger = logging.getLogger(__name__)
                logger.error(f"Failed to handle escrow logic in UpdateErrand: {e}", exc_info=True)
        
        # Send notification if status changed
        if 'status' in updates and updates['status'] != old_status:
            try:
                from apps.users.notifications import send_notification_to_user
                
                status_messages = {
                    'IN_PROGRESS': {
                        'title': 'Errand Accepted',
                        'body': 'Your errand has been accepted and is now in progress',
                    },
                    'COMPLETED': {
                        'title': 'Errand Completed',
                        'body': 'Your errand has been completed successfully',
                    },
                    'CANCELLED': {
                        'title': 'Errand Cancelled',
                        'body': 'Your errand has been cancelled',
                    },
                }
                
                if errand.status in status_messages:
                    msg = status_messages[errand.status]
                    send_notification_to_user(
                        user=errand.user,
                        title=msg['title'],
                        body=msg['body'],
                        data={
                            'type': f'errand_{errand.status.lower()}',
                            'errandId': str(errand.id),
                        }
                    )
            except Exception as e:
                # Don't fail the mutation if notification fails
                print(f"Failed to send notification: {e}")
        
        return UpdateErrand(errand=errand)


class AcceptErrand(graphene.Mutation):
    """Accept an errand as a runner - triggers escrow creation if price exists"""
    errand = graphene.Field(ErrandType)

    class Arguments:
        errand_id = graphene.ID(required=True)

    @login_required
    def mutate(self, info, errand_id):
        runner = info.context.user
        errand = Errand.objects.get(pk=errand_id)

        # Check if errand is available for acceptance
        if errand.status != Errand.Status.PENDING:
            raise GraphQLError(f"Errand is not available for acceptance. Current status: {errand.status}")
        
        # Check if errand is still open
        if not errand.is_open:
            raise GraphQLError("Errand is no longer open for acceptance")
        
        # Check if errand has expired
        if errand.expires_at and timezone.now() >= errand.expires_at:
            raise GraphQLError("Errand has expired")
        
        # Check if user is trying to accept their own errand
        if errand.user == runner:
            raise GraphQLError("You cannot accept your own errand")
        
        # Check if runner has runner role
        from apps.roles.models import Role
        runner_role = Role.objects.filter(name=Role.RUNNER).first()
        if runner_role:
            profile = getattr(runner, "profile", None)
            if not profile or not profile.roles.filter(id=runner_role.id).exists():
                raise GraphQLError("You must be a runner to accept errands")

        # Update errand with runner and status
        old_status = errand.status
        errand.runner = runner
        errand.status = Errand.Status.IN_PROGRESS
        errand.is_open = False  # Close the errand once accepted
        errand.save(update_fields=['runner', 'status', 'is_open', 'updated_at'])
        
        # Handle escrow logic - create escrow if price exists
        try:
            handle_errand_status_change(
                errand=errand,
                old_status=old_status,
                new_status=errand.status,
                runner=runner
            )
        except Exception as e:
            # Log error but don't fail the mutation
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Failed to handle escrow logic on errand acceptance: {e}")
        
        # Send notification to buyer
        try:
            from apps.users.notifications import send_notification_to_user
            send_notification_to_user(
                user=errand.user,
                title='Errand Accepted',
                body=f'Your errand has been accepted by {runner.email}',
                data={
                    'type': 'errand_accepted',
                    'errandId': str(errand.id),
                }
            )
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Failed to send notification: {e}")
        
        return AcceptErrand(errand=errand)


# =====================
# PAYMENT MUTATIONS
# =====================

class InitializePayment(graphene.Mutation):
    """Initialize Flutterwave payment for an escrow"""
    payment_link = graphene.String()
    transaction_id = graphene.String()
    tx_ref = graphene.String()
    success = graphene.Boolean()
    message = graphene.String()

    class Arguments:
        escrow_id = graphene.ID(required=True)

    @login_required
    def mutate(self, info, escrow_id):
        user = info.context.user
        
        try:
            escrow = Escrow.objects.get(pk=escrow_id)
            
            # Verify user is the buyer
            if escrow.buyer != user:
                raise GraphQLError("Not permitted. Only the buyer can initialize payment.")
            
            # Check if escrow is in valid state
            if escrow.status != Escrow.Status.PENDING:
                raise GraphQLError(f"Cannot initialize payment for escrow with status {escrow.status}")
            
            if not FLUTTERWAVE_AVAILABLE or not flutterwave_service:
                raise GraphQLError("Payment gateway not configured")
            
            import uuid
            tx_ref = f"ESCROW_{escrow.id}_{uuid.uuid4().hex[:8]}"
            buyer_email = escrow.buyer.email
            buyer_name = getattr(escrow.buyer, 'first_name', '') or buyer_email.split('@')[0]
            
            payment_result = flutterwave_service.initialize_payment(
                amount=escrow.amount,
                email=buyer_email,
                tx_ref=tx_ref,
                customer_name=buyer_name,
                meta={
                    'escrow_id': str(escrow.id),
                    'errand_id': str(escrow.errand.id),
                    'buyer_id': str(escrow.buyer.id),
                    'runner_id': str(escrow.runner.id) if escrow.runner else None
                }
            )
            
            # Update escrow with transaction ID
            escrow.transaction_id = payment_result.get('transaction_id') or tx_ref
            escrow.save(update_fields=['transaction_id'])
            
            return InitializePayment(
                payment_link=payment_result.get('payment_link'),
                transaction_id=payment_result.get('transaction_id', ''),
                tx_ref=tx_ref,
                success=True,
                message="Payment initialized successfully"
            )
            
        except Escrow.DoesNotExist:
            raise GraphQLError("Escrow not found")
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Failed to initialize payment: {e}", exc_info=True)
            raise GraphQLError(f"Failed to initialize payment: {str(e)}")


class VerifyPayment(graphene.Mutation):
    """Verify a Flutterwave payment transaction"""
    success = graphene.Boolean()
    message = graphene.String()
    transaction_id = graphene.String()
    amount = graphene.Decimal()
    payment_status = graphene.String()

    class Arguments:
        transaction_id = graphene.String(required=True)
        escrow_id = graphene.ID(required=True)

    @login_required
    def mutate(self, info, transaction_id, escrow_id):
        user = info.context.user
        
        try:
            escrow = Escrow.objects.get(pk=escrow_id)
            
            # Verify user is the buyer
            if escrow.buyer != user:
                raise GraphQLError("Not permitted. Only the buyer can verify payment.")
            
            if not FLUTTERWAVE_AVAILABLE or not flutterwave_service:
                raise GraphQLError("Payment gateway not configured")
            
            verification_result = flutterwave_service.verify_payment(transaction_id)
            
            # Update escrow with verified transaction ID
            if verification_result.get('payment_status') == 'successful':
                escrow.transaction_id = transaction_id
                escrow.save(update_fields=['transaction_id'])
            
            return VerifyPayment(
                success=verification_result.get('payment_status') == 'successful',
                message=f"Payment status: {verification_result.get('payment_status')}",
                transaction_id=transaction_id,
                amount=verification_result.get('amount', escrow.amount),
                payment_status=verification_result.get('payment_status', 'unknown')
            )
            
        except Escrow.DoesNotExist:
            raise GraphQLError("Escrow not found")
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Failed to verify payment: {e}", exc_info=True)
            raise GraphQLError(f"Failed to verify payment: {str(e)}")


class TransferToRunner(graphene.Mutation):
    """Transfer escrow funds to runner's bank account"""
    success = graphene.Boolean()
    message = graphene.String()
    transfer_id = graphene.String()

    class Arguments:
        escrow_id = graphene.ID(required=True)
        account_number = graphene.String(required=False)
        bank_code = graphene.String(required=False)
        account_name = graphene.String(required=False)
        use_saved_account = graphene.Boolean(default_value=False)

    @login_required
    def mutate(self, info, escrow_id, account_number=None, bank_code=None, account_name=None, use_saved_account=False):
        user = info.context.user
        
        try:
            escrow = Escrow.objects.get(pk=escrow_id)
            
            # Verify user is authorized (buyer or admin)
            if escrow.buyer != user and not user.is_staff:
                raise GraphQLError("Not permitted")
            
            # Check escrow status
            if escrow.status != Escrow.Status.PENDING:
                raise GraphQLError(f"Cannot transfer funds for escrow with status {escrow.status}")
            
            if not escrow.runner:
                raise GraphQLError("No runner assigned to this escrow")
            
            if not FLUTTERWAVE_AVAILABLE or not flutterwave_service:
                raise GraphQLError("Payment gateway not configured")
            
            # Get bank account details
            if use_saved_account:
                # Use runner's saved bank account
                runner_profile = getattr(escrow.runner, 'profile', None)
                if not runner_profile:
                    raise GraphQLError("Runner profile not found")
                
                account_number = runner_profile.bank_account_number
                bank_code = runner_profile.bank_code
                account_name = runner_profile.bank_account_name
                
                if not all([account_number, bank_code, account_name]):
                    raise GraphQLError("Runner has not set up bank account details")
            else:
                # Use provided account details
                if not all([account_number, bank_code, account_name]):
                    raise GraphQLError("Account details are required if not using saved account")
            
            import uuid
            transfer_result = flutterwave_service.transfer_funds(
                amount=escrow.amount,
                recipient_account_number=account_number,
                recipient_bank_code=bank_code,
                recipient_name=account_name,
                narration=f"Payment for errand {escrow.errand.id}",
                reference=f"TRF_{escrow.id}_{uuid.uuid4().hex[:8]}"
            )
            
            # Release escrow with transfer ID
            escrow.release(transaction_id=transfer_result.get('transfer_id'))
            
            return TransferToRunner(
                success=True,
                message="Funds transferred successfully",
                transfer_id=transfer_result.get('transfer_id', '')
            )
            
        except Escrow.DoesNotExist:
            raise GraphQLError("Escrow not found")
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Failed to transfer funds: {e}", exc_info=True)
            raise GraphQLError(f"Failed to transfer funds: {str(e)}")


class UpdateBankAccount(graphene.Mutation):
    """Update user's bank account details for receiving payments"""
    success = graphene.Boolean()
    message = graphene.String()

    class Arguments:
        account_number = graphene.String(required=True)
        bank_code = graphene.String(required=True)
        account_name = graphene.String(required=True)

    @login_required
    def mutate(self, info, account_number, bank_code, account_name):
        user = info.context.user
        
        try:
            from apps.users.models import UserProfile
            
            profile, created = UserProfile.objects.get_or_create(user=user)
            profile.bank_account_number = account_number
            profile.bank_code = bank_code
            profile.bank_account_name = account_name
            profile.save(update_fields=['bank_account_number', 'bank_code', 'bank_account_name', 'updated_at'])
            
            return UpdateBankAccount(
                success=True,
                message="Bank account details updated successfully"
            )
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Failed to update bank account: {e}", exc_info=True)
            raise GraphQLError(f"Failed to update bank account: {str(e)}")


class DeleteErrand(graphene.Mutation):
    class Arguments:
        id = graphene.ID(required=True)

    ok = graphene.Boolean()

    @login_required
    def mutate(self, info, id):
        errand = Errand.objects.get(pk=id)

        if errand.user != info.context.user:
            raise GraphQLError("Not permitted")

        errand.delete()
        return DeleteErrand(ok=True)

# =====================
# QUERIES
# =====================

class Query(graphene.ObjectType):
    node = relay.Node.Field()

    me = graphene.Field(UserType)
    errands = graphene.List(ErrandType)
    my_escrows = graphene.List(EscrowType)
    escrow = graphene.Field(EscrowType, errand_id=graphene.ID(required=True))

    @login_required
    def resolve_me(self, info):
        return info.context.user

    def resolve_errands(self, info):
        # Cache errand list for better performance
        from core.cache_utils import cache_queryset
        from django.conf import settings
        
        queryset = Errand.objects.all().order_by("-created_at")
        timeout = settings.CACHE_TIMEOUTS.get('errand_list', 60)
        
        # Only cache if caching is enabled
        if getattr(settings, 'CACHE_ENABLED', True):
            try:
                cached = cache_queryset(queryset, timeout=timeout, key_prefix='errand_list')
                if cached:
                    # Convert back to queryset-like object
                    from django.db import models
                    return [Errand.objects.get(pk=item['id']) if isinstance(item, dict) else item for item in cached]
            except Exception as e:
                import logging
                logger = logging.getLogger(__name__)
                logger.warning(f"Cache error in resolve_errands: {e}")
        
        return queryset
    
    @login_required
    def resolve_my_escrows(self, info):
        user = info.context.user
        from core.cache_utils import get_cache_key, cache_queryset
        from django.core.cache import cache
        from django.conf import settings
        
        queryset = Escrow.objects.filter(
            django_models.Q(buyer=user) | django_models.Q(runner=user)
        ).order_by("-created_at")
        
        # Cache user's escrows
        if getattr(settings, 'CACHE_ENABLED', True):
            try:
                cache_key = get_cache_key('user_escrows', user.id)
                timeout = settings.CACHE_TIMEOUTS.get('user_escrows', 300)
                cached = cache.get(cache_key)
                
                if cached is not None:
                    return cached
                
                result = list(queryset)
                cache.set(cache_key, result, timeout)
                return result
            except Exception as e:
                import logging
                logger = logging.getLogger(__name__)
                logger.warning(f"Cache error in resolve_my_escrows: {e}")
        
        return queryset
    
    @login_required
    def resolve_escrow(self, info, errand_id):
        user = info.context.user
        try:
            errand = Errand.objects.get(pk=errand_id)
            # Only allow buyer or runner to view escrow
            if errand.user != user and errand.runner != user:
                raise GraphQLError("Not permitted")
            return errand.escrow
        except Escrow.DoesNotExist:
            return None
    
    banks = graphene.List(graphene.JSONString, country=graphene.String(default_value='NG'))
    
    @login_required
    def resolve_banks(self, info, country='NG'):
        """Get list of banks for a country (for Flutterwave transfers)"""
        if not FLUTTERWAVE_AVAILABLE or not flutterwave_service:
            raise GraphQLError("Payment gateway not configured")
        
        # Cache banks list (changes infrequently)
        from core.cache_utils import get_cache_key
        from django.core.cache import cache
        from django.conf import settings
        
        cache_key = get_cache_key('banks_list', country)
        timeout = settings.CACHE_TIMEOUTS.get('banks_list', 86400)  # 24 hours
        
        if getattr(settings, 'CACHE_ENABLED', True):
            try:
                cached = cache.get(cache_key)
                if cached is not None:
                    return cached
            except Exception as e:
                import logging
                logger = logging.getLogger(__name__)
                logger.warning(f"Cache error in resolve_banks: {e}")
        
        try:
            banks_result = flutterwave_service.get_banks(country)
            banks = banks_result.get('banks', [])
            
            # Cache the result
            if getattr(settings, 'CACHE_ENABLED', True):
                try:
                    cache.set(cache_key, banks, timeout)
                except Exception as e:
                    import logging
                    logger = logging.getLogger(__name__)
                    logger.warning(f"Cache set error in resolve_banks: {e}")
            
            return banks
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Failed to fetch banks: {e}", exc_info=True)
            raise GraphQLError(f"Failed to fetch banks: {str(e)}")

# =====================
# ROOT SCHEMA
# =====================

class Mutation(graphene.ObjectType):
    # JWT
    token_auth = graphql_jwt.ObtainJSONWebToken.Field()
    verify_token = graphql_jwt.Verify.Field()
    refresh_token = graphql_jwt.Refresh.Field()

    # Google Auth (no frontend token verification; use backend allauth + session tokens)
    verify_google_token = VerifyGoogleToken.Field()
    issue_session_tokens = IssueSessionTokens.Field()

    # User
    update_user_location = UpdateUserLocation.Field()
    become_runner = BecomeRunner.Field()
    register_fcm_token = RegisterFCMToken.Field()
    unregister_fcm_token = UnregisterFCMToken.Field()

    # Errands
    create_errand = CreateErrand.Field()
    save_errand_draft = SaveErrandDraft.Field()
    update_errand = UpdateErrand.Field()
    accept_errand = AcceptErrand.Field()
    delete_errand = DeleteErrand.Field()
    
    # Payments
    initialize_payment = InitializePayment.Field()
    verify_payment = VerifyPayment.Field()
    transfer_to_runner = TransferToRunner.Field()
    update_bank_account = UpdateBankAccount.Field()


schema = graphene.Schema(query=Query, mutation=Mutation)
