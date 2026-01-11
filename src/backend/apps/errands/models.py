from django.contrib.auth import get_user_model
from django.db import models
from django.utils import timezone

User = get_user_model()

class Errand(models.Model):
    class Type(models.TextChoices):
        ONE_WAY = "ONE_WAY"
        ROUND_TRIP = "ROUND_TRIP"

    class Status(models.TextChoices):
        PENDING = "PENDING" # open, searching for runners
        IN_PROGRESS = "IN_PROGRESS" # accepted by a runner
        COMPLETED = "COMPLETED"
        CANCELLED = "CANCELLED"
        EXPIRED = "EXPIRED"

    user = models.ForeignKey(User, on_delete=models.CASCADE)
    type = models.CharField(max_length=20, choices=Type.choices)
    instructions = models.TextField()
    speed = models.CharField(max_length=10)
    payment_method = models.CharField(max_length=20)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)

    # Optional image
    image_url = models.URLField(blank=True, null=True)

    # Open window for runner acceptance
    is_open = models.BooleanField(default=True)
    expires_at = models.DateTimeField(blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def refresh_open_state(self):
        """Toggle is_open and status to EXPIRED if past expires_at and not terminal."""
        if self.expires_at and self.status not in [self.Status.COMPLETED, self.Status.CANCELLED, self.Status.EXPIRED]:
            if timezone.now() >= self.expires_at:
                self.is_open = False
                self.status = self.Status.EXPIRED
                self.save(update_fields=["is_open", "status", "updated_at"])
