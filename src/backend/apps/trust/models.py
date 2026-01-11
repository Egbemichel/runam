from django.contrib.auth import get_user_model
from django.db import models

User = get_user_model()

class TrustScoreEvent(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="trust_events",
    )

    delta = models.SmallIntegerField()
    reason = models.CharField(max_length=255)

    created_at = models.DateTimeField(auto_now_add=True)
