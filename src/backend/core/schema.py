import graphene
import graphql_jwt
from django.contrib.auth import get_user_model
from graphene import relay
from graphene_django import DjangoObjectType
from graphql import GraphQLError
from graphql_jwt.decorators import login_required
from django.contrib.auth import login

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
from errand_location.models import ErrandLocation

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

class ErrandType(DjangoObjectType):
    locations = graphene.List(ErrandLocationType)

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
        )

    def resolve_locations(self, info):
        return self.locations.all()


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

    @login_required
    def resolve_me(self, info):
        return info.context.user

    def resolve_errands(self, info):
        return Errand.objects.all().order_by("-created_at")

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
    delete_errand = DeleteErrand.Field()


schema = graphene.Schema(query=Query, mutation=Mutation)
