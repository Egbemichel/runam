from allauth.socialaccount.adapter import DefaultSocialAccountAdapter
from django.db import transaction

class CustomSocialAccountAdapter(DefaultSocialAccountAdapter):

    def populate_user(self, request, sociallogin, data):
        """
        Google → User fields (before save)
        """
        user = super().populate_user(request, sociallogin, data)

        extra = sociallogin.account.extra_data

        user.email = extra.get('email')
        user.name = extra.get('name')  # Google gives full name
        user.avatar = extra.get('picture')

        return user

    @transaction.atomic
    def save_user(self, request, sociallogin, form=None):
        """
        App defaults (after user exists)
        """
        user = super().save_user(request, sociallogin, form)

        # ---- DEFAULT ROLE ----
        if not user.roles.exists():
            from apps.roles.models import Role
            default_role = Role.objects.get(name=Role.BUYER)
            user.roles.add(default_role)

        # ---- DEFAULT TRUST SCORE ----
        if user.trust_score is None:
            user.trust_score = 60

        user.is_active = True
        user.save()
        return user
