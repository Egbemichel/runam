from django.contrib.auth import get_user_model
from django.db import models
from django.utils import timezone
from decimal import Decimal

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

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='errands')
    type = models.CharField(max_length=20, choices=Type.choices)
    instructions = models.TextField()
    speed = models.CharField(max_length=10)
    payment_method = models.CharField(max_length=20)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)

    # Price and runner for escrow
    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Price for the errand (required for escrow)"
    )
    runner = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='accepted_errands',
        help_text="Runner who accepted the errand"
    )

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
                old_status = self.status
                self.is_open = False
                self.status = self.Status.EXPIRED
                self.save(update_fields=["is_open", "status", "updated_at"])
                
                # Handle escrow refund when errand expires
                try:
                    from apps.escrow.services import handle_errand_status_change
                    handle_errand_status_change(
                        errand=self,
                        old_status=old_status,
                        new_status=self.Status.EXPIRED
                    )
                except Exception as e:
                    # Don't fail if escrow handling fails
                    import logging
                    logger = logging.getLogger(__name__)
                    logger.error(f"Failed to handle escrow on expiry: {e}")
