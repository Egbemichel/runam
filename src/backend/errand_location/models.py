from django.db import models
from apps.errands.models import Errand

class ErrandLocation(models.Model):
    errand = models.ForeignKey(Errand, related_name="locations", on_delete=models.CASCADE)
    kind = models.CharField(
        max_length=10,
        choices=[("GO_TO", "Go To"), ("RETURN_TO", "Return To")]
    )
    latitude = models.FloatField()
    longitude = models.FloatField()
    address = models.TextField()

