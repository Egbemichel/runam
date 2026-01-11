from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import models
from django.utils import timezone

User = get_user_model()
class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')

    # Moved attributes from custom User
    avatar = models.URLField(blank=True, null=True)
    trust_score = models.PositiveSmallIntegerField(default=60)

    # Optional extras
    phone = models.CharField(max_length=32, blank=True, null=True)
    date_of_birth = models.DateField(blank=True, null=True)

    # Roles association (attach to profile to avoid touching built-in User)
    roles = models.ManyToManyField(
        'roles.Role',
        related_name='user_profiles',
        blank=True,
    )

    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Profile({self.user.email})"
