from django.conf import settings
from django.contrib.auth import get_user_model
from google.auth.transport import requests
from google.oauth2 import id_token
from graphql import GraphQLError
from allauth.socialaccount.models import SocialAccount
from apps.roles.models import Role
from apps.users.models import UserProfile
from graphql_jwt.shortcuts import get_token
from graphql_jwt.refresh_token.shortcuts import create_refresh_token

User = get_user_model()


def verify_google_id_token(id_token_str: str) -> dict:
    try:
        return id_token.verify_oauth2_token(
            id_token_str,
            requests.Request(),
            settings.GOOGLE_CLIENT_ID,
        )
    except Exception:
        raise GraphQLError("Invalid Google token")


def get_or_create_google_user(payload: dict) -> User:
    email = payload.get("email")
    sub = payload.get("sub")
    full_name = payload.get("name", "")
    picture = payload.get("picture", "")

    if not email or not sub:
        raise GraphQLError("Invalid Google account data")

    # Create or get built-in User
    user, created = User.objects.get_or_create(
        email=email,
        defaults={},
    )

    # Best-effort: split name into first/last
    if full_name:
        parts = full_name.split(" ", 1)
        user.first_name = parts[0]
        user.last_name = parts[1] if len(parts) > 1 else ""
        user.save(update_fields=["first_name", "last_name"])

    # Ensure SocialAccount exists
    SocialAccount.objects.get_or_create(
        user=user,
        provider="google",
        uid=sub,
        defaults={"extra_data": payload},
    )

    # Ensure profile exists and update extras
    profile, _ = UserProfile.objects.get_or_create(user=user)
    if picture and not profile.avatar:
        profile.avatar = picture
    if profile.trust_score is None:
        profile.trust_score = 60
    if created and profile.roles.count() == 0:
        try:
            buyer_role = Role.objects.get(name=Role.BUYER)
            profile.roles.add(buyer_role)
        except Role.DoesNotExist:
            pass
    profile.save()

    return user


def get_access_token(user: User) -> str:
    return get_token(user)


def get_refresh_token(user: User) -> str:
    return create_refresh_token(user)
