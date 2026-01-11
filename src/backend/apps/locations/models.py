from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import models

User = get_user_model()

class LocationMode(models.TextChoices):
    DEVICE = "DEVICE", "Device"
    STATIC = "STATIC", "Static"

class UserLocation(models.Model):
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="location",
    )

    mode = models.CharField(
        max_length=10,
        choices=LocationMode.choices,
        default=LocationMode.STATIC,
    )

    latitude = models.FloatField()
    longitude = models.FloatField()

    address = models.TextField(blank=True)

    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.email} – {self.mode}"
