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
    
    # Bank account details for payments (runners)
    bank_account_number = models.CharField(max_length=20, blank=True, null=True, help_text="Bank account number")
    bank_code = models.CharField(max_length=10, blank=True, null=True, help_text="Flutterwave bank code")
    bank_account_name = models.CharField(max_length=255, blank=True, null=True, help_text="Account holder name")

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


class FCMToken(models.Model):
    """Stores Firebase Cloud Messaging tokens for push notifications"""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='fcm_tokens')
    token = models.CharField(max_length=255, unique=True)
    device_id = models.CharField(max_length=255, blank=True, null=True, help_text="Optional device identifier")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        unique_together = [['user', 'token']]
        indexes = [
            models.Index(fields=['user', 'is_active']),
        ]

    def __str__(self):
        return f"FCMToken({self.user.email[:20]}...)"