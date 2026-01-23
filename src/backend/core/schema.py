# type: ignore
import graphene
import graphql_jwt
from django.contrib.auth import get_user_model
from graphene_django import DjangoObjectType
from graphql import GraphQLError
from graphql_jwt.decorators import login_required
from django.db import transaction
from django.utils import timezone
from datetime import timedelta
from apps.errands.models import ErrandTask, ErrandOffer

from apps.errands.models import Errand
from apps.locations.models import UserLocation, LocationMode
from apps.roles.models import Role
from apps.users.models import UserProfile
from apps.users.services import (
    verify_google_id_token,
    get_or_create_google_user,
    get_access_token,
    get_refresh_token,
)
from errand_location.models import ErrandLocation
from apps.errands.schema import UploadImage
from runners.services import get_nearby_runners, distance_between
from apps.errands.services import accept_offer as services_accept_offer
from apps.trust.models import Rating
from apps.trust.services import recalculate_trust_score

import logging

User = get_user_model()

logger = logging.getLogger(__name__)

# =====================
# GRAPHQL TYPES
# =====================


class RunnerType(graphene.ObjectType):
    id = graphene.ID()
    name = graphene.String()
    image_url = graphene.String()
    avatar_url = graphene.String()  # Add this for frontend compatibility
    trust_score = graphene.Float()
    latitude = graphene.Float()
    longitude = graphene.Float()
    distance_m = graphene.Float()
    has_pending_offer = graphene.Boolean()

    def resolve_avatar_url(self, info):
        # Prefer explicit image_url, fallback to profile avatar
        if hasattr(self, 'image_url') and self.image_url:
            return self.image_url
        profile = getattr(self, 'profile', None)
        return getattr(profile, 'avatar', None) if profile else None


class RoleType(DjangoObjectType):
    class Meta:
        model = Role
        fields = ("name",)


class ErrandLocationType(DjangoObjectType):
    class Meta:
        model = ErrandLocation
        fields = (
            "id",
            "latitude",
            "longitude",
            "address",
            "mode",
        )


class LocationType(DjangoObjectType):
    class Meta:
        model = UserLocation
        fields = (
            "id",
            "mode",
            "latitude",
            "longitude",
            "address",
        )

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
        # interfaces = (relay.Node,)
        fields = (
            "id",
            "email",
            "is_active",
            "is_staff",
            "roles",
            "location",
            "trust_score",
            # expose single location via resolver
        )

    def resolve_roles(self, info):
        profile = getattr(self, "profile", None)
        return profile.roles.all() if profile else []

    def resolve_location(self, info):
        # This handles the OneToOne relation from User -> UserLocation
        return getattr(self, 'location', None)

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

class ErrandTaskType(DjangoObjectType):
    class Meta:
        model = ErrandTask
        fields = ("id", "description", "price")

class ErrandStatusType(graphene.ObjectType):
    errand_id = graphene.ID()
    status = graphene.String()
    is_open = graphene.Boolean()
    expires_at = graphene.DateTime()
    created_at = graphene.DateTime()
    runner = graphene.Field(RunnerType)
    nearby_runners = graphene.List(RunnerType)

class ErrandType(DjangoObjectType):
    go_to = graphene.Field(ErrandLocationType)
    return_to = graphene.Field(ErrandLocationType)

    runnerId = graphene.String()
    runnerName = graphene.String()
    runnerTrustScore = graphene.Int()

    # New: expose creating user fields expected by frontend
    userId = graphene.String()
    userName = graphene.String()
    userTrustScore = graphene.Int()

    # Frontend expects this
    price = graphene.Float()

    # Image URL (prefer explicit errand.image_url, fallback to requester's profile.avatar)
    imageUrl = graphene.String()

    isOpen = graphene.Boolean()
    expiresAt = graphene.DateTime()

    # New pricing breakdown
    tasks = graphene.List(ErrandTaskType)
    errandValue = graphene.Int()
    serviceFee = graphene.Int()
    distanceFee = graphene.Int()
    totalPrice = graphene.Int()

    class Meta:
        model = Errand
        fields = (
            "id",
            "type",
            "speed",
            "payment_method",
            "status",
            "created_at",
            "image_url",
        )

    # --------------------
    # Location
    # --------------------
    def resolve_go_to(self, info):
        return getattr(self, "go_to", None)

    def resolve_return_to(self, info):
        return getattr(self, "return_to", None)

    # --------------------
    # Image
    # --------------------
    def resolve_imageUrl(self, info):
        # Prefer explicitly uploaded errand image
        errand_img = getattr(self, 'image_url', None)
        if errand_img:
            return errand_img

        # Fallback to the requester's profile avatar (Google picture) if available
        creator = getattr(self, 'user', None)
        if creator:
            profile = getattr(creator, 'profile', None)
            if profile and getattr(profile, 'avatar', None):
                return profile.avatar

        return None

    # --------------------
    # User info (who created the errand)
    # --------------------
    def resolve_userId(self, info):
        return str(getattr(self.user, "id", None)) if getattr(self, 'user', None) else None

    def resolve_userName(self, info):
        profile = getattr(getattr(self, 'user', None), 'profile', None)
        if profile and getattr(profile, 'name', None):
            return getattr(profile, 'name')
        user = getattr(self, 'user', None)
        if not user:
            return None
        first = getattr(user, 'first_name', '')
        last = getattr(user, 'last_name', '')
        full = " ".join([n for n in [first, last] if n]).strip()
        return full or None

    def resolve_userTrustScore(self, info):
        profile = getattr(getattr(self, 'user', None), 'profile', None)
        return getattr(profile, 'trust_score', None) if profile else None

    # --------------------
    # Runner info
    # --------------------
    def resolve_runnerId(self, info):
        return getattr(self.runner, "id", None) if hasattr(self, "runner") else None

    def resolve_runnerName(self, info):
        profile = getattr(self.runner, "profile", None)
        # Prefer profile name if available, otherwise fallback to user names
        pname = getattr(profile, "name", None) if profile else None
        if pname:
            return pname
        first = getattr(self.runner, 'first_name', '')
        last = getattr(self.runner, 'last_name', '')
        full = " ".join([n for n in [first, last] if n]).strip()
        return full or None
    def resolve_runnerTrustScore(self, info):
        profile = getattr(self.runner, "profile", None)
        return getattr(profile, "trust_score", None) if profile else None

    # --------------------
    # Tasks & pricing
    # --------------------
    def resolve_tasks(self, info):
        return self.tasks.all()

    def resolve_serviceFee(self, info):
        return self.service_fee()

    def resolve_distanceFee(self, info):
        return self.distance_fee()

    def resolve_totalPrice(self, info):
        return self.total_price()

    # 🔥 IMPORTANT: frontend price === backend total_price
    def resolve_price(self, info):
        return self.total_price()

    # --------------------
    # State
    # --------------------
    def resolve_isOpen(self, info):
        return getattr(self, "is_open", False)

    def resolve_expiresAt(self, info):
        return getattr(self, "expires_at", None)



class SaveErrandDraft(graphene.Mutation):
    errand = graphene.Field(ErrandType)

    class Arguments:
        id = graphene.ID(required=False)
        type = graphene.String(required=False)
        tasks = graphene.JSONString(required=False)  # [{description, price}]
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
                status=Errand.Status.PENDING,
            )

        # Update scalar fields
        for field in ["type", "speed", "payment_method"]:
            if data.get(field) is not None:
                setattr(errand, field, data[field])

        errand.save()

        # 🔁 Replace tasks if provided
        if data.get("tasks") is not None:
            errand.tasks.all().delete()

            tasks = data["tasks"]
            if not isinstance(tasks, list):
                raise GraphQLError("Tasks must be a list")

            for task in tasks:
                description = task.get("description")
                price = task.get("price")

                if not description or price is None:
                    raise GraphQLError("Each task requires description and price")

                ErrandTask.objects.create(
                    errand=errand,
                    description=description,
                    price=int(price),
                )

        # 🔁 Replace locations if provided
        if data.get("go_to"):
            ErrandLocation.objects.filter(
                errand=errand,
                mode=LocationMode.GO_TO
            ).delete()

        if data.get("return_to"):
            ErrandLocation.objects.filter(
                errand=errand,
                mode=LocationMode.RETURN_TO
            ).delete()

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
        # login(request, user, backend="django.contrib.auth.backends.ModelBackend")

        access = get_access_token(user)
        refresh = get_refresh_token(user)
        return VerifyGoogleToken(access=access, refresh=refresh, user=user)

# =====================
# USER MUTATIONS
# =====================

class UpdateUserLocation(graphene.Mutation):
    class Arguments:
        mode = graphene.String(required=True)  # "DEVICE" or "STATIC"
        latitude = graphene.Float(required=True)
        longitude = graphene.Float(required=True)
        address = graphene.String(required=False)

    location = graphene.Field(LocationType)

    @login_required
    def mutate(self, info, mode, latitude, longitude, address=None):
        user = info.context.user

        # Upsert user's current location (UserLocation is OneToOne)
        location, _ = UserLocation.objects.update_or_create(
            user=user,
            defaults={
                "mode": mode,
                "latitude": latitude,
                "longitude": longitude,
                "address": address,
            },
        )

        return UpdateUserLocation(location=location)



class BecomeRunner(graphene.Mutation):
    ok = graphene.Boolean()

    @login_required
    def mutate(self, info):
        user = info.context.user

        profile, _ = UserProfile.objects.get_or_create(user=user)
        runner_role = Role.objects.get(name=Role.RUNNER)

        profile.roles.add(runner_role)

        return BecomeRunner(ok=True)


class RunnerCandidate(graphene.ObjectType):
    id = graphene.ID()
    name = graphene.String()
    latitude = graphene.Float()
    longitude = graphene.Float()
    # Graphene handles the conversion, but being explicit prevents frontend bugs
    trust_score = graphene.Int(name="trustScore")
    distance_m = graphene.Float(name="distanceM")
    image_url = graphene.String(name="imageUrl")


# New: Offer type used by polling queries (myPendingOffers)
class ErrandOfferType(graphene.ObjectType):
    id = graphene.ID()
    errandId = graphene.ID()
    price = graphene.Int()
    expiresAt = graphene.DateTime()
    expiresIn = graphene.Int()
    errand = graphene.Field(ErrandType)

    def resolve_id(self, info):
        return str(self.id)

    def resolve_errandId(self, info):
        return getattr(self.errand, 'id', None)

    def resolve_price(self, info):
        # Price shown in offers is the errand's base value (frontend expects a numeric field)
        try:
            return int(self.errand.errand_value())
        except Exception:
            return None

    def resolve_expiresAt(self, info):
        return getattr(self, 'expires_at', None)

    def resolve_expiresIn(self, info):
        exp = getattr(self, 'expires_at', None)
        if not exp:
            return None
        delta = exp - timezone.now()
        return int(delta.total_seconds()) if delta.total_seconds() > 0 else 0

    def resolve_errand(self, info):
        return getattr(self, 'errand', None)

# =====================
# ERRAND MUTATIONS
# =====================


class AcceptErrandOffer(graphene.Mutation):
    ok = graphene.Boolean()
    errand = graphene.Field('core.schema.ErrandType')
    total_price = graphene.Int()
    buyer_trust_score = graphene.Int()
    runner_trust_score = graphene.Int()

    class Arguments:
        offer_id = graphene.ID(required=True)

    @login_required
    def mutate(self, info, offer_id):
        user = info.context.user

        try:
            with transaction.atomic():
                offer = ErrandOffer.objects.select_related("errand", "errand__user", "errand__user__profile").select_for_update().get(
                    id=offer_id,
                    runner=user,
                    status=ErrandOffer.Status.PENDING
                )

                # 2. Check Expiry
                if offer.expires_at and offer.expires_at <= timezone.now():
                    offer.status = ErrandOffer.Status.EXPIRED
                    offer.save(update_fields=["status"])
                    raise GraphQLError("Offer has expired")

                # 3. Mark Offer Accepted
                offer.status = ErrandOffer.Status.ACCEPTED
                offer.responded_at = timezone.now()
                offer.save(update_fields=["status", "responded_at"])

                # 4. Update Errand State via Service
                services_accept_offer(offer.errand, user)

                # Refresh from DB to get the updated status/runner info
                offer.errand.refresh_from_db()

                # Get trust scores
                buyer_trust = getattr(getattr(offer.errand.user, 'profile', None), 'trust_score', None)
                runner_trust = getattr(getattr(user, 'profile', None), 'trust_score', None)
                total_price = getattr(offer.errand, 'quoted_total_price', None)

                return AcceptErrandOffer(
                    ok=True,
                    errand=offer.errand,
                    total_price=total_price,
                    buyer_trust_score=buyer_trust,
                    runner_trust_score=runner_trust
                )

        except ErrandOffer.DoesNotExist:
            raise GraphQLError("Offer not found or already processed")
        except Exception as e:
            logger.exception("AcceptErrandOffer Error: %s", e)
            raise GraphQLError(str(e))


class RejectErrandOffer(graphene.Mutation):
    """Runner rejects an ErrandOffer: mark the offer REJECTED and record responded_at.
    This does not expire other offers or change errand state; frontend polling will continue.
    """
    ok = graphene.Boolean()

    class Arguments:
        offer_id = graphene.ID(required=True)

    @login_required
    def mutate(self, info, offer_id):
        user = info.context.user
        logger.info("RejectErrandOffer called by user=%s for offer_id=%s", getattr(user, 'id', None), offer_id)

        try:
            offer = ErrandOffer.objects.select_related('errand').get(
                id=offer_id,
                runner=user,
                status=ErrandOffer.Status.PENDING,
            )
        except Exception as e:
            logger.exception("RejectErrandOffer: failed to fetch offer=%s runner=%s: %s", offer_id, getattr(user, 'id', None), e)
            raise GraphQLError("Offer not found or not permitted")

        # If already expired, mark expired and abort
        if offer.expires_at and offer.expires_at <= timezone.now():
            offer.status = ErrandOffer.Status.EXPIRED
            offer.save(update_fields=['status'])
            logger.warning("RejectErrandOffer: offer %s already expired", offer_id)
            raise GraphQLError("Offer has expired")

        # Mark rejected and persist
        offer.status = ErrandOffer.Status.REJECTED
        offer.responded_at = timezone.now()
        offer.save(update_fields=['status', 'responded_at'])

        logger.info("Offer %s marked REJECTED by runner %s", offer_id, getattr(user, 'id', None))

        # No further side effects here; matching continues for other runners via polling.
        return RejectErrandOffer(ok=True)


class CreateErrand(graphene.Mutation):
    errand_id = graphene.ID()
    runners = graphene.List(RunnerCandidate)

    class Arguments:
        type = graphene.String(required=True)
        tasks = graphene.JSONString(required=True)  # [{ description, price }]
        speed = graphene.String(required=True)
        payment_method = graphene.String(required=False)
        go_to = graphene.JSONString(required=True)
        return_to = graphene.JSONString(required=False)
        image_url = graphene.String(required=False)
        user_location = graphene.JSONString(required=False)  # Optional: {mode, latitude, longitude, address}

    @login_required
    def mutate(self, info, **kwargs):
        user = info.context.user
        # Log entry and a short summary of the incoming payload for debugging 400s
        logger.info("CreateErrand called by user=%s payload_keys=%s", getattr(user, 'id', None), list(kwargs.keys()))

        # Log HTTP request metadata/body snippet to help diagnose malformed requests (avoid printing secrets)
        try:
            request = info.context
            content_type = getattr(request, 'content_type', None) or (request.META.get('CONTENT_TYPE') if hasattr(request, 'META') else None)
            logger.debug("CreateErrand: HTTP content_type=%s", content_type)
            # request.body may be bytes; log only a small prefix to avoid huge logs
            raw = getattr(request, 'body', b'')
            if raw:
                snippet = raw[:1000] if isinstance(raw, (bytes, bytearray)) else str(raw)[:1000]
                logger.debug("CreateErrand: HTTP body snippet=%s", snippet)
        except Exception:
            logger.exception("CreateErrand: failed to log raw HTTP request body")

        try:
            # If the frontend provided a current device location for the authenticated user,
            # upsert it now so matching uses the freshest coordinates.
            user_location_payload = kwargs.get('user_location')
            if user_location_payload:
                try:
                    logger.info("CreateErrand: user_location payload received for user=%s", getattr(user, 'id', None))
                    # user_location_payload is a dict because Graphene JSONString is parsed
                    ul_mode = user_location_payload.get('mode') or None
                    ul_lat = user_location_payload.get('latitude')
                    ul_lon = user_location_payload.get('longitude')
                    ul_address = user_location_payload.get('address') or ''

                    logger.debug("CreateErrand: user_location details mode=%s lat=%s lon=%s addr=%s", ul_mode, ul_lat, ul_lon, ul_address)

                    if ul_lat is not None and ul_lon is not None:
                        # If mode provided and valid, use it; otherwise keep existing
                        mode_to_save = ul_mode if ul_mode in (LocationMode.DEVICE, LocationMode.STATIC) else (getattr(getattr(user, 'location', None), 'mode', LocationMode.STATIC))

                        # Upsert the user's UserLocation row
                        UserLocation.objects.update_or_create(
                            user=user,
                            defaults={
                                'mode': mode_to_save,
                                'latitude': float(ul_lat),
                                'longitude': float(ul_lon),
                                'address': ul_address,
                            }
                        )
                        logger.info("UserLocation upserted for user=%s mode=%s lat=%s lon=%s", getattr(user, 'id', None), mode_to_save, ul_lat, ul_lon)
                except Exception as e:
                    logger.exception("Failed to upsert UserLocation for user=%s: %s", getattr(user, 'id', None), e)

            user_location = getattr(user, "location", None)
            mode = user_location.mode if user_location else LocationMode.STATIC

            # 1️⃣ Create Errand (NO instructions anymore)
            try:
                errand = Errand.objects.create(
                    user=user,
                    type=kwargs["type"],
                    speed=kwargs["speed"],
                    payment_method=kwargs.get("payment_method"),
                    image_url=kwargs.get("image_url"),
                    expires_at=timezone.now() + timedelta(hours=2),
                )
                logger.info("Errand created id=%s user=%s type=%s", errand.id, getattr(user, 'id', None), kwargs.get("type"))
            except Exception as e:
                logger.exception("Failed to create Errand for user=%s payload error: %s", getattr(user, 'id', None), e)
                raise

            # 2️⃣ Create tasks
            tasks_data = kwargs.get("tasks")
            logger.debug("CreateErrand: tasks_payload=%s", tasks_data)

            if not isinstance(tasks_data, list) or len(tasks_data) == 0:
                logger.warning("CreateErrand called with no tasks by user=%s", getattr(user, 'id', None))
                raise GraphQLError("At least one task is required")

            for idx, task in enumerate(tasks_data, start=1):
                try:
                    description = task.get("description")
                    price = task.get("price")

                    if not description or price is None:
                        logger.warning("Invalid task in CreateErrand by user=%s at index=%s: %s", getattr(user, 'id', None), idx, task)
                        raise GraphQLError("Each task must have description and price")

                    ErrandTask.objects.create(
                        errand=errand,
                        description=description,
                        price=int(price),
                    )
                    logger.debug("Created ErrandTask for errand=%s: %s - %s", errand.id, description, price)
                except GraphQLError:
                    raise
                except Exception as e:
                    logger.exception("Failed creating task for errand=%s index=%s error=%s", getattr(errand, 'id', None), idx, e)
                    raise GraphQLError("Failed creating task")

            # 3️⃣ Create GO-TO location
            go_to_data = kwargs.get("go_to")
            logger.debug("CreateErrand: go_to payload=%s", go_to_data)
            try:
                go_to_loc = ErrandLocation.objects.create(
                    errand=errand,
                    address=go_to_data.get("address"),
                    latitude=go_to_data.get("latitude") or go_to_data.get("lat"),
                    longitude=go_to_data.get("longitude") or go_to_data.get("lng"),
                    mode=mode,
                )
                logger.info("ErrandLocation GO_TO created for errand=%s lat=%s lng=%s", errand.id, go_to_loc.latitude, go_to_loc.longitude)
            except Exception as e:
                logger.exception("Failed to create GO_TO location for errand=%s: %s", getattr(errand, 'id', None), e)
                raise GraphQLError("Invalid go_to location")

            # 4️⃣ Optional RETURN-TO
            return_to_loc = None
            return_to_data = kwargs.get("return_to")
            if return_to_data:
                try:
                    return_to_loc = ErrandLocation.objects.create(
                        errand=errand,
                        address=return_to_data.get("address"),
                        latitude=return_to_data.get("latitude") or return_to_data.get("lat"),
                        longitude=return_to_data.get("longitude") or return_to_data.get("lng"),
                        mode=mode,
                    )
                    logger.info("ErrandLocation RETURN_TO created for errand=%s lat=%s lng=%s", errand.id, return_to_loc.latitude, return_to_loc.longitude)
                except Exception as e:
                    logger.exception("Failed to create RETURN_TO for errand=%s: %s", getattr(errand, 'id', None), e)
                    raise GraphQLError("Invalid return_to location")

            # 5️⃣ Attach locations
            errand.go_to = go_to_loc
            errand.return_to = return_to_loc
            errand.save(update_fields=["go_to", "return_to"])
            logger.debug("Errand %s saved with locations", errand.id)

            # 6️⃣ Compute nearby runners and return them immediately to frontend
            try:
                candidates = get_nearby_runners(errand)
                logger.info("Found %s candidate runners for errand=%s", len(candidates), errand.id)
                runners_payload = []
                for r in candidates:
                    dist = distance_between(getattr(r, 'location', None), go_to_loc)
                    profile = getattr(r, 'profile', None)
                    runners_payload.append(RunnerCandidate(
                        id=str(r.id),
                        name=(getattr(profile, 'name', None) or f"{getattr(r, 'first_name', '')} {getattr(r, 'last_name', '')}".strip()),
                        latitude=getattr(r.location, 'latitude', None),
                        longitude=getattr(r.location, 'longitude', None),
                        trust_score=getattr(profile, 'trust_score', None),
                        distance_m=float(dist or 0.0),
                    ))
                    logger.debug("Candidate runner %s: distance_m=%s trust=%s", getattr(r, 'id', None), dist, getattr(profile, 'trust_score', None))
            except Exception as ex:
                logger.exception("Error computing nearby runners for errand=%s: %s", errand.id, ex)
                runners_payload = []

            # 7️⃣ Start matching process (async)
            from apps.errands.tasks import start_errand_matching

            # Run matching in a background thread so the HTTP response returns fast.
            import threading
            try:
                logger.info("Starting start_errand_matching in background thread for errand=%s", errand.id)
                threading.Thread(target=lambda: start_errand_matching(errand.id), daemon=True).start()
            except Exception as e:
                logger.exception("Failed to start background thread for start_errand_matching errand=%s: %s", errand.id, e)

            logger.info("CreateErrand completed for errand=%s responding with %s candidates", errand.id, len(runners_payload))
            return CreateErrand(errand_id=errand.id, runners=runners_payload)

        except GraphQLError:
            # GraphQL errors are expected for bad payloads; surface them but keep a log
            logger.warning("CreateErrand: GraphQLError for user=%s payload_keys=%s", getattr(user, 'id', None), list(kwargs.keys()))
            raise
        except Exception as e:
            # Unexpected error: log full details for debugging 400s and re-raise
            logger.exception("CreateErrand: unexpected error for user=%s payload_keys=%s: %s", getattr(user, 'id', None), list(kwargs.keys()), e)
            raise

class FetchMyErrands(graphene.Mutation):
    class Arguments:
        pass  # No arguments needed, we'll use the authenticated user

    errands = graphene.List(ErrandType)
    success = graphene.Boolean()
    message = graphene.String()

    @login_required
    def mutate(self, info, **kwargs):
        user = info.context.user
        try:
            errands = Errand.objects.filter(user=user).order_by("-created_at")
            return FetchMyErrands(
                errands=errands,
                success=True,
                message="Errands fetched successfully"
            )
        except Exception as e:
            return FetchMyErrands(
                errands=None,
                success=False,
                message=str(e)
            )

class FetchAssignedErrands(graphene.Mutation):
    """Return errands where the current authenticated user is the assigned runner.
    Note: this is implemented as a mutation per request, but a query would be more REST/GraphQL-idiomatic.
    """
    errands = graphene.List(ErrandType)
    success = graphene.Boolean()
    message = graphene.String()

    @login_required
    def mutate(self, info, **kwargs):
        user = info.context.user
        try:
            errands = Errand.objects.filter(runner=user).order_by("-created_at")
            return FetchAssignedErrands(
                errands=errands,
                success=True,
                message="Assigned errands fetched successfully"
            )
        except Exception as e:
            return FetchAssignedErrands(
                errands=None,
                success=False,
                message=str(e)
            )

class UpdateErrand(graphene.Mutation):
    class Arguments:
        id = graphene.ID(required=True)
        type = graphene.String()
        tasks = graphene.JSONString()  # [{description, price}]
        speed = graphene.String()
        payment_method = graphene.String()
        status = graphene.String()
        image_url = graphene.String()
        is_open = graphene.Boolean()
        expires_at = graphene.DateTime()

    errand = graphene.Field(ErrandType)

    @login_required
    def mutate(self, info, id, **updates):
        errand = Errand.objects.get(pk=id)

        if errand.user != info.context.user:
            raise GraphQLError("Not permitted")

        # Update scalar fields
        for field in [
            "type",
            "speed",
            "payment_method",
            "status",
            "image_url",
            "is_open",
            "expires_at",
        ]:
            if updates.get(field) is not None:
                setattr(errand, field, updates[field])

        errand.save()

        # 🔁 Replace tasks if provided
        if updates.get("tasks") is not None:
            errand.tasks.all().delete()

            tasks = updates["tasks"]
            if not isinstance(tasks, list):
                raise GraphQLError("Tasks must be a list")

            for task in tasks:
                description = task.get("description")
                price = task.get("price")

                if not description or price is None:
                    raise GraphQLError("Each task requires description and price")

                ErrandTask.objects.create(
                    errand=errand,
                    description=description,
                    price=int(price),
                )

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
# RATING MUTATION
# =====================


class CreateRating(graphene.Mutation):
    class Arguments:
        errand_id = graphene.ID(required=True)
        ratee_id = graphene.ID(required=True)
        score = graphene.Int(required=True)
        comment = graphene.String()

    ok = graphene.Boolean()
    rating = graphene.Field(lambda: RatingType)
    new_trust_score = graphene.Int()

    @login_required
    def mutate(self, info, errand_id, ratee_id, score, comment=None):
        user = info.context.user
        from django.contrib.auth import get_user_model
        User = get_user_model()
        try:
            errand = Errand.objects.get(pk=errand_id)
            ratee = User.objects.get(pk=ratee_id)

            # Prevent duplicate rating
            if Rating.objects.filter(errand=errand, rater=user, ratee=ratee).exists():
                raise GraphQLError("You have already rated this user for this errand.")

            # Create the rating
            rating = Rating.objects.create(
                errand=errand,
                rater=user,
                ratee=ratee,
                score=score,
                comment=comment
            )

            # Recalculate the trust score for the ratee
            new_score = recalculate_trust_score(ratee)

            return CreateRating(ok=True, rating=rating, new_trust_score=new_score)
        except Exception as e:
            raise GraphQLError(str(e))

# Add the RatingType for the mutation
class RatingType(DjangoObjectType):
    class Meta:
        model = Rating
        fields = ("id", "errand", "rater", "ratee", "score", "comment", "created_at")

# =====================
# QUERIES
# =====================

class Query(graphene.ObjectType):
    my_errands = graphene.List(ErrandType)
    # Exposed as `myPendingOffers` in GraphQL (Graphene will camelCase the field name)
    my_pending_offers = graphene.List(ErrandOfferType, name='myPendingOffers')
    # Expose errandStatus query for polling (buyer or assigned runner)
    errand_status = graphene.Field(ErrandStatusType, errand_id=graphene.ID(required=True), name='errandStatus')
    # Added aliases to support frontend candidate queries for assigned errands
    my_assigned_errands = graphene.List(ErrandType, name='myAssignedErrands')
    assigned_errands = graphene.List(ErrandType, name='assignedErrands')
    my_runs = graphene.List(ErrandType, name='myRuns')
    errand = graphene.Field(ErrandType, id=graphene.ID(required=True))

    @login_required
    def resolve_my_errands(self, info, **kwargs):
        user = info.context.user
        return Errand.objects.filter(user=user).order_by("-created_at")

    @login_required
    def resolve_my_pending_offers(self, info, **kwargs):
        user = info.context.user
        now = timezone.now()
        qs = ErrandOffer.objects.select_related('errand').filter(
            runner=user,
            status=ErrandOffer.Status.PENDING,
            expires_at__gt=now
        ).order_by('expires_at')
        logger.info("resolve_my_pending_offers: user=%s found=%s", getattr(user, 'id', None), qs.count())
        # Log each pending offer id & expiry to help debug 400s on frontend
        for of in qs:
            logger.debug("PendingOffer id=%s errand=%s expires_at=%s", getattr(of, 'id', None), getattr(getattr(of, 'errand', None), 'id', None), getattr(of, 'expires_at', None))
        return qs

    # Resolver helper: errands assigned to current authenticated runner
    def _resolve_assigned_for_runner(self, info):
        user = info.context.user
        if not user.is_authenticated:
            raise Exception("Authentication required")
        qs = Errand.objects.filter(runner=user).order_by("-created_at")
        logger.info("resolve_assigned_errands: runner=%s found=%s", getattr(user, 'id', None), qs.count())
        return qs

    @login_required
    def resolve_my_assigned_errands(self, info, **kwargs):
        return self._resolve_assigned_for_runner(info)

    @login_required
    def resolve_assigned_errands(self, info, **kwargs):
        return self._resolve_assigned_for_runner(info)

    @login_required
    def resolve_my_runs(self, info, **kwargs):
        return self._resolve_assigned_for_runner(info)

    @login_required
    def resolve_user(self, info, id):
        try:
            return User.objects.get(pk=id)
        except User.DoesNotExist:
            return None

    @login_required
    def resolve_errand_status(self, info, errand_id):
        """Resolver for errandStatus(errandId: ID!) — allows buyer OR assigned runner to poll."""
        user = info.context.user
        if not user.is_authenticated:
            raise Exception("Authentication required")

        try:
            from django.db.models import Q
            # Use a single Q expression combining id and (user OR runner)
            errand = Errand.objects.get(Q(id=errand_id) & (Q(user=user) | Q(runner=user)))
        except Errand.DoesNotExist:
            logger.warning("resolve_errand_status: errand %s not found for user=%s", errand_id, getattr(user, 'id', None))
            return None

        logger.info("[GraphQL] Poll for errand=%s, status=%s by user=%s", errand_id, errand.status, getattr(user, 'id', None))

        result = ErrandStatusType(
            errand_id=errand.id,
            status=errand.status,
            is_open=errand.is_open,
            expires_at=errand.expires_at,
            created_at=errand.created_at
        )

        # assigned runner info
        if errand.runner:
            profile = getattr(errand.runner, 'profile', None)
            loc = getattr(errand.runner, 'location', None)
            result.runner = RunnerType(
                id=errand.runner.id,
                name=getattr(profile, 'name', f"{errand.runner.first_name} {errand.runner.last_name}").strip(),
                latitude=loc.latitude if loc else None,
                longitude=loc.longitude if loc else None,
            )

        # nearby runners when searching
        if errand.status == Errand.Status.PENDING and errand.is_open:
            nearby_list = []
            try:
                candidates = get_nearby_runners(errand)[:10]
                logger.info("resolve_errand_status: found %s nearby candidates for errand=%s", len(candidates), errand.id)
                for runner in candidates:
                    runner_loc = getattr(runner, 'location', None)
                    if not runner_loc:
                        continue
                    nearby_list.append(RunnerType(
                        id=runner.id,
                        latitude=float(runner_loc.latitude),
                        longitude=float(runner_loc.longitude),
                        distance_m=distance_between(runner_loc, errand.go_to)
                    ))
                result.nearby_runners = nearby_list
            except Exception:
                logger.exception("Error fetching nearby runners for errand=%s", errand.id)
                result.nearby_runners = []

        return result

    @login_required
    def resolve_errand(self, info, id):
        user = info.context.user
        from django.db.models import Q
        try:
            # Only allow access if user is the creator or assigned runner
            errand = Errand.objects.get(Q(id=id) & (Q(user=user) | Q(runner=user)))
            return errand
        except Errand.DoesNotExist:
            return None

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

    # Errands
    create_errand = CreateErrand.Field()
    # Expose accept errand offer mutation so frontend can call acceptErrandOffer(offerId: ...)
    accept_errand_offer = AcceptErrandOffer.Field()
    # Expose reject errand offer mutation so frontend can call rejectErrandOffer(offerId: ...)
    reject_errand_offer = RejectErrandOffer.Field()
    fetch_my_errands = FetchMyErrands.Field()
    # New: fetch errands assigned to the authenticated runner
    fetch_assigned_errands = FetchAssignedErrands.Field()
    upload_image = UploadImage.Field()
    save_errand_draft = SaveErrandDraft.Field()
    update_errand = UpdateErrand.Field()
    delete_errand = DeleteErrand.Field()

    # New: Rating mutation
    create_rating = CreateRating.Field()


schema = graphene.Schema(
    query=Query,
    mutation=Mutation,
)
