# type: ignore
import graphene
import graphql_jwt
from django.contrib.auth import get_user_model
from graphene_django import DjangoObjectType
from graphql import GraphQLError
from graphql_jwt.decorators import login_required
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
    trust_score = graphene.Float()
    latitude = graphene.Float()
    longitude = graphene.Float()
    distance_m = graphene.Float()
    has_pending_offer = graphene.Boolean()

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

    # Frontend expects this
    price = graphene.Float()

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
# =====================
# ERRAND MUTATIONS
# =====================


class AcceptErrandOffer(graphene.Mutation):
    ok = graphene.Boolean()

    class Arguments:
        offer_id = graphene.ID(required=True)

    @login_required
    def mutate(self, info, offer_id):
        user = info.context.user
        logger.info("AcceptErrandOffer called by user=%s for offer_id=%s", getattr(user, 'id', None), offer_id)

        offer = ErrandOffer.objects.select_related("errand").get(
            id=offer_id,
            runner=user,
            status=ErrandOffer.Status.PENDING
        )

        offer.status = ErrandOffer.Status.ACCEPTED
        offer.responded_at = timezone.now()
        offer.save(update_fields=["status", "responded_at"])

        logger.info("Offer %s marked ACCEPTED by runner %s", offer_id, getattr(user, 'id', None))

        # Delegate the rest to the service layer which handles pricing, webhooks, notifications
        services_accept_offer(offer.errand, user)

        logger.info("accept_offer delegated for errand_id=%s runner=%s", offer.errand.id, getattr(user, 'id', None))

        return AcceptErrandOffer(ok=True)


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
        logger.info("CreateErrand called by user=%s", getattr(user, 'id', None))

        # If the frontend provided a current device location for the authenticated user,
        # upsert it now so matching uses the freshest coordinates.
        user_location_payload = kwargs.get('user_location')
        if user_location_payload:
            try:
                # user_location_payload is a dict because Graphene JSONString is parsed
                ul_mode = user_location_payload.get('mode') or None
                ul_lat = user_location_payload.get('latitude')
                ul_lon = user_location_payload.get('longitude')
                ul_address = user_location_payload.get('address') or ''

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
        errand = Errand.objects.create(
            user=user,
            type=kwargs["type"],
            speed=kwargs["speed"],
            payment_method=kwargs.get("payment_method"),
            image_url=kwargs.get("image_url"),
            expires_at=timezone.now() + timedelta(hours=2),
        )
        logger.info("Errand created id=%s user=%s type=%s", errand.id, getattr(user, 'id', None), kwargs["type"])

        # 2️⃣ Create tasks
        tasks_data = kwargs["tasks"]

        if not isinstance(tasks_data, list) or len(tasks_data) == 0:
            logger.warning("CreateErrand called with no tasks by user=%s", getattr(user, 'id', None))
            raise GraphQLError("At least one task is required")

        for task in tasks_data:
            description = task.get("description")
            price = task.get("price")

            if not description or price is None:
                logger.warning("Invalid task in CreateErrand by user=%s: %s", getattr(user, 'id', None), task)
                raise GraphQLError("Each task must have description and price")

            ErrandTask.objects.create(
                errand=errand,
                description=description,
                price=int(price),
            )
            logger.debug("Created ErrandTask for errand=%s: %s - %s", errand.id, description, price)

        # 3️⃣ Create GO-TO location
        go_to_data = kwargs["go_to"]
        go_to_loc = ErrandLocation.objects.create(
            errand=errand,
            address=go_to_data.get("address"),
            latitude=go_to_data.get("latitude") or go_to_data.get("lat"),
            longitude=go_to_data.get("longitude") or go_to_data.get("lng"),
            mode=mode,
        )
        logger.info("ErrandLocation GO_TO created for errand=%s lat=%s lng=%s", errand.id, go_to_loc.latitude, go_to_loc.longitude)

        # 4️⃣ Optional RETURN-TO
        return_to_loc = None
        return_to_data = kwargs.get("return_to")
        if return_to_data:
            return_to_loc = ErrandLocation.objects.create(
                errand=errand,
                address=return_to_data.get("address"),
                latitude=return_to_data.get("latitude") or return_to_data.get("lat"),
                longitude=return_to_data.get("longitude") or return_to_data.get("lng"),
                mode=mode,
            )
            logger.info("ErrandLocation RETURN_TO created for errand=%s lat=%s lng=%s", errand.id, return_to_loc.latitude, return_to_loc.longitude)

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

        # If Celery is configured to run tasks eagerly (memory broker) we'll
        # start the matching in a background thread to avoid blocking the HTTP response.
        from django.conf import settings as _dj_settings
        import threading
        if getattr(_dj_settings, 'CELERY_TASK_ALWAYS_EAGER', False):
            logger.info("CELERY_TASK_ALWAYS_EAGER=True: starting start_errand_matching in background thread for errand=%s", errand.id)
            threading.Thread(target=lambda: start_errand_matching(errand.id), daemon=True).start()
        else:
            try:
                logger.info("Enqueueing start_errand_matching via Celery for errand=%s", errand.id)
                # Try to enqueue via Celery; if the broker or client libs are missing
                # this can raise (kombu/redis errors). Fall back to a background thread.
                start_errand_matching.delay(errand.id)
            except Exception as e:
                logger.exception('Failed to enqueue start_errand_matching via Celery, falling back to background thread: %s', e)
                threading.Thread(target=lambda: start_errand_matching(errand.id), daemon=True).start()

        logger.info("CreateErrand completed for errand=%s responding with %s candidates", errand.id, len(runners_payload))
        return CreateErrand(errand_id=errand.id, runners=runners_payload)

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
# QUERIES
# =====================

class Query(graphene.ObjectType):
    errand_status = graphene.Field(ErrandStatusType, errand_id=graphene.ID(required=True))

    def resolve_errand_status(self, info, errand_id):
        user = info.context.user
        if not user.is_authenticated:
            raise Exception("Authentication required")

        # 1. Fetch Errand
        try:
            errand = Errand.objects.get(id=errand_id, user=user)
        except Errand.DoesNotExist:
            return None

        logger.info(f"[GraphQL] Poll for errand={errand_id}, status={errand.status}")

        # 2. Map Base Data
        result = ErrandStatusType(
            errand_id=errand.id,
            status=errand.status,
            is_open=errand.is_open,
            expires_at=errand.expires_at,
            created_at=errand.created_at
        )

        # 3. Handle Assigned Runner
        if errand.runner:
            profile = getattr(errand.runner, 'profile', None)
            loc = getattr(errand.runner, 'location', None)
            result.runner = RunnerType(
                id=errand.runner.id,
                name=getattr(profile, 'name', f"{errand.runner.first_name} {errand.runner.last_name}").strip(),
                image_url=getattr(profile, 'avatar', None),
                trust_score=getattr(profile, 'trust_score', 0),
                latitude=loc.latitude if loc else None,
                longitude=loc.longitude if loc else None
            )

        # 4. Handle Nearby Runners (if Pending)
        if errand.status == 'PENDING' and errand.is_open:
            nearby_list = []
            try:
                candidates = get_nearby_runners(errand)[:10]
                for runner in candidates:
                    runner_loc = getattr(runner, 'location', None)
                    if not runner_loc:
                        continue

                    profile = getattr(runner, 'profile', None)
                    has_offer = ErrandOffer.objects.filter(
                        errand=errand,
                        runner=runner,
                        status='PENDING'
                    ).exists()

                    nearby_list.append(RunnerType(
                        id=runner.id,
                        name=getattr(profile, 'name', f"{runner.first_name} {runner.last_name}").strip(),
                        image_url=getattr(profile, 'avatar', None),
                        latitude=float(runner_loc.latitude),
                        longitude=float(runner_loc.longitude),
                        trust_score=getattr(profile, 'trust_score', 0),
                        distance_m=distance_between(runner_loc, errand.go_to),
                        has_pending_offer=has_offer
                    ))
                result.nearby_runners = nearby_list
            except Exception as e:
                logger.exception(f"Error fetching nearby runners: {e}")
                result.nearby_runners = []

        return result


class Query(graphene.ObjectType):
    my_errands = graphene.List(ErrandType)

    @login_required
    def resolve_my_errands(self, info, **kwargs):
        user = info.context.user
        return Errand.objects.filter(user=user).order_by("-created_at")


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
    fetch_my_errands = FetchMyErrands.Field()
    upload_image = UploadImage.Field()
    save_errand_draft = SaveErrandDraft.Field()
    update_errand = UpdateErrand.Field()
    delete_errand = DeleteErrand.Field()


schema = graphene.Schema(
    query=Query,
    mutation=Mutation,
)
