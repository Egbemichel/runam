from os import access

import graphene
from django.conf import settings
from google.auth.transport import requests
from graphene_django import DjangoObjectType
from graphene import relay
from django.contrib.auth import get_user_model
from graphql_jwt.decorators import login_required
import graphql_jwt
from graphql import GraphQLError
from graphql_jwt.shortcuts import get_token
from google.oauth2 import id_token as google_id_token

from errands.models import Errand
User = get_user_model()


class UserType(DjangoObjectType):
    class Meta:
        model = get_user_model()
        interfaces = (relay.Node,)
        fields = (
            'id',
            'username',
            'email',
            'first_name',
            'last_name',
            'avatar',
        )

# --------------------
# GOOGLE AUTH MUTATION
# --------------------
class VerifyGoogleToken(graphene.Mutation):
    class Arguments:
        id_token = graphene.String(required=True)

    access = graphene.String()
    user = graphene.Field(UserType)

    def mutate(self, info, id_token):
        try:
            payload = google_id_token.verify_oauth2_token(
                id_token,
                requests.Request(),
                settings.GOOGLE_CLIENT_ID,
            )
        except ValueError:
            raise GraphQLError("Invalid Google ID token")

        email = payload.get("email")
        name = payload.get("name", "")
        picture = payload.get("picture", "")

        if not email:
            raise GraphQLError("Google account has no email")

        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                "username": email,
                "first_name": name.split(" ")[0],
                "last_name": " ".join(name.split(" ")[1:]),
                "avatar": picture,
            },
        )

        if picture and user.avatar != picture:
            user.avatar = picture
            user.save()

        token = get_token(user)

        return VerifyGoogleToken(access=token, user=user)


class ErrandType(DjangoObjectType):
    class Meta:
        model = Errand
        interfaces = (relay.Node,)
        fields = (
            'id',
            'requester',
            'title',
            'description',
            'pickup_latitude',
            'pickup_longitude',
            'dropoff_latitude',
            'dropoff_longitude',
            'budget',
            'status',
            'created_at',
        )


class Query(graphene.ObjectType):
    node = relay.Node.Field()

    me = graphene.Field(UserType)
    errand = relay.Node.Field(ErrandType)
    errands = graphene.List(
        ErrandType,
        status=graphene.String(required=False),
        requester_id=graphene.Int(required=False),
    )

    @login_required
    def resolve_me(self, info):
        return info.context.user

    def resolve_errands(self, info, status=None, requester_id=None):
        qs = Errand.objects.all().order_by('-created_at')
        if status:
            qs = qs.filter(status=status)
        if requester_id:
            qs = qs.filter(requester_id=requester_id)
        return qs


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
        pickup_latitude = graphene.Float()
        pickup_longitude = graphene.Float()
        dropoff_latitude = graphene.Float()
        dropoff_longitude = graphene.Float()
        budget = graphene.Decimal()
        status = graphene.String()

    errand = graphene.Field(ErrandType)

    @login_required
    def mutate(self, info, id, **updates):
        try:
            errand = Errand.objects.get(pk=id)
        except Errand.DoesNotExist:
            raise Exception("Errand not found")

        if errand.requester_id != info.context.user.id:
            raise Exception("Not permitted")

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
        try:
            errand = Errand.objects.get(pk=id)
        except Errand.DoesNotExist:
            return DeleteErrand(ok=False)

        if errand.requester_id != info.context.user.id:
            raise Exception("Not permitted")

        errand.delete()
        return DeleteErrand(ok=True)


class Mutation(graphene.ObjectType):
    # JWT
    token_auth = graphql_jwt.ObtainJSONWebToken.Field()
    verify_token = graphql_jwt.Verify.Field()
    refresh_token = graphql_jwt.Refresh.Field()

    # Errands
    create_errand = CreateErrand.Field()
    update_errand = UpdateErrand.Field()
    delete_errand = DeleteErrand.Field()

    # Google login mutation
    verify_google_token = VerifyGoogleToken.Field()


schema = graphene.Schema(query=Query, mutation=Mutation)
