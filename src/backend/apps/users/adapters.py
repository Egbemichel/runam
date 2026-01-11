from allauth.socialaccount.adapter import DefaultSocialAccountAdapter
from django.db import transaction

from apps.users.models import UserProfile
from apps.roles.models import Role


class CustomSocialAccountAdapter(DefaultSocialAccountAdapter):

    def populate_user(self, request, sociallogin, data):
        """
        Map Google → built-in User fields (before save)
        """
        user = super().populate_user(request, sociallogin, data)
        extra = sociallogin.account.extra_data

        # Built-in User fields
        user.email = extra.get('email')
        full_name = extra.get('name') or ''
        if full_name:
            parts = full_name.split(' ', 1)
            user.first_name = parts[0]
            user.last_name = parts[1] if len(parts) > 1 else ''

        return user

    @transaction.atomic
    def save_user(self, request, sociallogin, form=None):
        """
        After user exists: ensure profile, set defaults, assign role
        """
        user = super().save_user(request, sociallogin, form)
        extra = sociallogin.account.extra_data or {}

        # Ensure a profile exists
        profile, _ = UserProfile.objects.get_or_create(user=user)

        # Avatar from Google
        if not profile.avatar:
            profile.avatar = extra.get('picture')

        # Default trust score
        if profile.trust_score is None:
            profile.trust_score = 60

        # Default role assignment on first signup
        if profile.roles.count() == 0:
            try:
                default_role = Role.objects.get(name=Role.BUYER)
                profile.roles.add(default_role)
            except Role.DoesNotExist:
                # Roles not seeded yet; skip silently
                pass

        profile.save()

        # Activate user
        user.is_active = True
        user.save(update_fields=["is_active", "first_name", "last_name"])  # names may have been set
        return user
