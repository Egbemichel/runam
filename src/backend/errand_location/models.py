from django.db import models
from apps.errands.models import Errand
from apps.locations.models import LocationMode

class ErrandLocation(models.Model):
    errand = models.ForeignKey(
        "errands.Errand",
        on_delete=models.CASCADE,
        related_name="locations"
    )
    latitude = models.FloatField()
    longitude = models.FloatField()
    address = models.TextField(blank=True)
    mode = models.CharField(
        max_length=10,
        choices=LocationMode.choices,
    )


