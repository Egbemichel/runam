import graphene
from django.conf import settings
from django.contrib.auth import get_user_model
from google.auth.transport import requests
from google.oauth2 import id_token
from graphene import relay
from graphene_django import DjangoObjectType
from graphql import GraphQLError
from graphql_jwt.decorators import login_required
from graphql_jwt.shortcuts import get_token
import graphql_jwt

from apps.errands.models import Errand
from apps.roles.models import Role
from apps.locations.models import Location
from django.contrib.auth import login

from allauth.socialaccount.models import SocialLogin, SocialAccount

from allauth.socialaccount.adapter import get_adapter
from allauth.account.utils import perform_login





User = get_user_model()

# =====================
# GRAPHQL TYPES
# =====================

class RoleType(DjangoObjectType):
    class Meta:
        model = Role
        fields = ("name",)


class LocationType(DjangoObjectType):
    class Meta:
        model = Location
        fields = (
            "id",
            "latitude",
            "longitude",
            "label",
            "type",
            "is_active",
            "created_at",
        )


# =====================
# USER TYPE FIX
# =====================

class UserType(DjangoObjectType):
    roles = graphene.List(RoleType)
    locations = graphene.List(LocationType)
    location = graphene.Field(LocationType, required=False)  # make optional

    class Meta:
        model = User
        interfaces = (relay.Node,)
        fields = (
            "id",
            "email",
            "name",
            "avatar",
            "trust_score",
            "is_active",
            "is_staff",
            "created_at",
            "updated_at",
            "roles",
            "locations",
        )

    def resolve_roles(self, info):
        # Always return a list
        return self.roles.all() if hasattr(self, "roles") else []

    def resolve_location(self, info):
        # Return the first active location or None
        if hasattr(self, "locations"):
            return self.locations.filter(is_active=True).first()
        return None



class ErrandType(DjangoObjectType):
    class Meta:
        model = Errand
        interfaces = (relay.Node,)
        fields = (
            "id",
            "requester",
            "title",
            "description",
            "pickup_latitude",
            "pickup_longitude",
            "dropoff_latitude",
            "dropoff_longitude",
            "budget",
            "status",
            "created_at",
        )

# =====================
# GOOGLE TOKEN VERIFY
# =====================

def verify_google_token(token):
    try:
        return id_token.verify_oauth2_token(
            token,
            requests.Request(),
            settings.GOOGLE_CLIENT_ID,
        )
    except Exception:
        raise GraphQLError("Invalid Google token")

# =====================
# AUTH MUTATIONS
# =====================

# =====================
# GOOGLE TOKEN VERIFY MUTATION FIX
# =====================

class VerifyGoogleToken(graphene.Mutation):
    class Arguments:
        id_token = graphene.String(required=True)

    access = graphene.String()
    user = graphene.Field(UserType)

    def mutate(self, info, id_token):
        payload = verify_google_token(id_token)

        email = payload.get("email")
        sub = payload.get("sub")
        name = payload.get("name", "")
        picture = payload.get("picture", "")

        if not email or not sub:
            raise GraphQLError("Invalid Google account data")

        # 1. Get or create user
        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                "name": name,
                "avatar": picture,
                "trust_score": 60,
            },
        )

        # 2. Ensure SocialAccount exists (THIS replaces complete_social_login)
        SocialAccount.objects.get_or_create(
            user=user,
            provider="google",
            uid=sub,
            defaults={"extra_data": payload},
        )

        # 3. Assign default role on first signup
        if created:
            buyer_role = Role.objects.get(name=Role.BUYER)
            user.roles.add(buyer_role)

        # 4. Log user in (required for JWT)
        request = info.context
        login(request, user, backend="django.contrib.auth.backends.ModelBackend")

        # 5. Issue JWT
        token = get_token(user)

        return VerifyGoogleToken(access=token, user=user)

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

        location = Location.objects.create(
            latitude=latitude,
            longitude=longitude,
            is_preferred=is_preferred,
            user=user,
        )

        # user.location = location
        user.save(update_fields=["location"])

        return UpdateUserLocation(location=location)


class BecomeRunner(graphene.Mutation):
    ok = graphene.Boolean()

    @login_required
    def mutate(self, info):
        user = info.context.user
        runner_role = Role.objects.get(name=Role.RUNNER)

        if user.roles.filter(id=runner_role.id).exists():
            return BecomeRunner(ok=True)

        user.roles.add(runner_role)
        return BecomeRunner(ok=True)

# =====================
# ERRAND MUTATIONS
# =====================

class CreateErrand(graphene.Mutation):
    class Arguments:
        title = graphene.String(required=True)
        description = graphene.String(required=True)
        pickup_latitude = graphene.Float(required=True)
        pickup_longitude = graphene.Float(required=True)
        dropoff_latitude = graphene.Float(required=True)
        dropoff_longitude = graphene.Float(required=True)
        budget = graphene.Decimal(required=True)

    errand = graphene.Field(ErrandType)

    @login_required
    def mutate(self, info, **kwargs):
        user = info.context.user
        errand = Errand.objects.create(requester=user, **kwargs)
        return CreateErrand(errand=errand)


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

        if errand.requester != info.context.user:
            raise GraphQLError("Not permitted")

        for field, value in updates.items():
            if value is not None:
                setattr(errand, field, value)

        errand.save()
        return UpdateErrand(errand=errand)


class DeleteErrand(graphene.Mutation):
    class Arguments:
        id = graphene.ID(required=True)

    ok = graphene.Boolean()

    @login_required
    def mutate(self, info, id):
        errand = Errand.objects.get(pk=id)

        if errand.requester != info.context.user:
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

    # Google Auth
    verify_google_token = VerifyGoogleToken.Field()

    # User
    update_user_location = UpdateUserLocation.Field()
    become_runner = BecomeRunner.Field()

    # Errands
    create_errand = CreateErrand.Field()
    update_errand = UpdateErrand.Field()
    delete_errand = DeleteErrand.Field()


schema = graphene.Schema(query=Query, mutation=Mutation)
