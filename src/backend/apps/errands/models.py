from django.contrib.auth import get_user_model
from django.db import models
from django.utils import timezone
from django.apps import apps

User = get_user_model()

class Errand(models.Model):
    quoted_distance_fee = models.PositiveIntegerField(default=0)
    quoted_service_fee = models.PositiveIntegerField(default=0)
    quoted_total_price = models.PositiveIntegerField(default=0)

    class Type(models.TextChoices):
        ONE_WAY = "ONE_WAY"
        ROUND_TRIP = "ROUND_TRIP"

    class PaymentMethod(models.TextChoices):
        CASH = "CASH"
        ONLINE = "ONLINE"

    class Status(models.TextChoices):
        PENDING = "PENDING" # open, searching for runners
        IN_PROGRESS = "IN_PROGRESS" # accepted by a runner
        COMPLETED = "COMPLETED"
        CANCELLED = "CANCELLED"
        EXPIRED = "EXPIRED"

    user = models.ForeignKey(User, on_delete=models.CASCADE)
    type = models.CharField(max_length=20, choices=Type.choices)
    speed = models.CharField(max_length=10)
    payment_method = models.CharField(
        max_length=20,
        choices=PaymentMethod.choices
    )
    go_to = models.ForeignKey(
        'errand_location.ErrandLocation',
        null=True,
        on_delete=models.CASCADE,
        related_name='errands_go_to'
    )
    return_to = models.ForeignKey(
        'errand_location.ErrandLocation',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='errands_return_to'
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)

    # Optional image
    image_url = models.URLField(blank=True, null=True)

    # Open window for runner acceptance
    is_open = models.BooleanField(default=True)
    expires_at = models.DateTimeField(blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    runner = models.ForeignKey(
        User,
        null=True,
        blank=True,
        related_name="accepted_errands",
        on_delete=models.SET_NULL
    )
    accepted_at = models.DateTimeField(null=True, blank=True)

    def refresh_open_state(self):
        """Toggle is_open and status to EXPIRED if past expires_at and not terminal."""
        if self.expires_at and self.status not in [self.Status.COMPLETED, self.Status.CANCELLED, self.Status.EXPIRED]:
            if timezone.now() >= self.expires_at:
                self.is_open = False
                self.status = self.Status.EXPIRED
                self.save(update_fields=["is_open", "status", "updated_at"])

    def errand_value(self):
        return sum(task.price for task in self.tasks.all())

    def service_fee(self):
        return int(self.errand_value() * 0.2)

    def distance_fee(self):
        # placeholder – integrate maps later
        return 0

    def total_price(self):
        return self.errand_value() + self.service_fee() + self.distance_fee()

def get_errand_location_model():
    return apps.get_model('errand_location', 'ErrandLocation')


class ErrandOffer(models.Model):

    class Status(models.TextChoices):
        PENDING = "PENDING", "Pending"
        ACCEPTED = "ACCEPTED", "Accepted"
        REJECTED = "REJECTED", "Rejected"
        EXPIRED = "EXPIRED", "Expired"

    errand = models.ForeignKey(
        Errand,
        on_delete=models.CASCADE,
        related_name="offers"
    )
    runner = models.ForeignKey(User, on_delete=models.CASCADE)

    position = models.PositiveIntegerField(help_text="Order of offer")

    status = models.CharField(
        max_length=10,
        choices=Status.choices,
        default=Status.PENDING
    )

    expires_at = models.DateTimeField()
    responded_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("errand", "runner")
        ordering = ["position"]



class ErrandTask(models.Model):
    errand = models.ForeignKey(
        Errand,
        related_name="tasks",
        on_delete=models.CASCADE
    )
    description = models.CharField(max_length=255)
    price = models.PositiveIntegerField(help_text="Price in XAF")

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.description} - XAF {self.price}"

