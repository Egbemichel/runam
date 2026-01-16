import graphene
import graphql_jwt
from django.contrib.auth import get_user_model
from graphene_django import DjangoObjectType
from graphql import GraphQLError
from graphql_jwt.decorators import login_required
from django.utils import timezone
from datetime import timedelta
from apps.errands.models import ErrandTask

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
        return getattr(self.runner, "name", None) if hasattr(self, "runner") else None

    # --------------------
    # Tasks & pricing
    # --------------------
    def resolve_tasks(self, info):
        return self.tasks.all()

    def resolve_errandValue(self, info):
        return self.errand_value()

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
        if data.get("go_to") or data.get("return_to"):
            ErrandLocation.objects.filter(errand=errand).delete()

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
        runner_role = Role.objects.get(name=Role.RUNNER)

        profile = getattr(user, "profile", None)
        if not profile:
            profile = UserProfile.objects.create(user=user)

        if profile.roles.filter(id=runner_role.id).exists():
            return BecomeRunner(ok=True)

        profile.roles.add(runner_role)
        return BecomeRunner(ok=True)

# =====================
# ERRAND MUTATIONS
# =====================

class CreateErrand(graphene.Mutation):
    errand_id = graphene.ID()

    class Arguments:
        type = graphene.String(required=True)
        tasks = graphene.JSONString(required=True)  # [{ description, price }]
        speed = graphene.String(required=True)
        payment_method = graphene.String(required=False)
        go_to = graphene.JSONString(required=True)
        return_to = graphene.JSONString(required=False)
        image_url = graphene.String(required=False)

    @login_required
    def mutate(self, info, **kwargs):
        user = info.context.user

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

        # 2️⃣ Create tasks
        tasks_data = kwargs["tasks"]

        if not isinstance(tasks_data, list) or len(tasks_data) == 0:
            raise GraphQLError("At least one task is required")

        for task in tasks_data:
            description = task.get("description")
            price = task.get("price")

            if not description or price is None:
                raise GraphQLError("Each task must have description and price")

            ErrandTask.objects.create(
                errand=errand,
                description=description,
                price=int(price),
            )

        # 3️⃣ Create GO-TO location
        go_to_data = kwargs["go_to"]
        go_to_loc = ErrandLocation.objects.create(
            errand=errand,
            address=go_to_data.get("address"),
            latitude=go_to_data.get("latitude") or go_to_data.get("lat"),
            longitude=go_to_data.get("longitude") or go_to_data.get("lng"),
            mode=mode,
        )

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

        # 5️⃣ Attach locations
        errand.go_to = go_to_loc
        errand.return_to = return_to_loc
        errand.save(update_fields=["go_to", "return_to"])

        return CreateErrand(errand_id=errand.id)

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

