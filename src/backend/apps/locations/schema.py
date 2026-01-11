import graphene
from graphene_django import DjangoObjectType
from graphql_jwt.decorators import login_required
from .models import UserLocation, LocationMode

class UserLocationType(DjangoObjectType):
    class Meta:
        model = UserLocation
        fields = "__all__"


class UpdateUserLocation(graphene.Mutation):
    location = graphene.Field(UserLocationType)

    class Arguments:
        mode = graphene.String(required=True)
        latitude = graphene.Float(required=True)
        longitude = graphene.Float(required=True)
        address = graphene.String(required=False)

    @login_required
    def mutate(self, info, mode, latitude, longitude, address=None):
        user = info.context.user

        location, _ = UserLocation.objects.update_or_create(
            user=user,
            defaults={
                "mode": mode,
                "latitude": latitude,
                "longitude": longitude,
                "address": address or "",
            },
        )

        return UpdateUserLocation(location=location)
