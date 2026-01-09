from django.db import models


class Location(models.Model):
    DEVICE = "DEVICE"
    PREFERRED = "PREFERRED"

    LOCATION_TYPE_CHOICES = [
        (DEVICE, "Device"),
        (PREFERRED, "Preferred"),
    ]

    user = models.ForeignKey(
        "users.User",
        on_delete=models.CASCADE,
        related_name="locations",
    )

    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    label = models.CharField(max_length=255, blank=True)

    type = models.CharField(
        max_length=10,
        choices=LOCATION_TYPE_CHOICES,
        default=DEVICE,
    )

    is_active = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)