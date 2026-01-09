from django.db import models


class TrustScoreEvent(models.Model):
    user = models.ForeignKey(
        "users.User",
        on_delete=models.CASCADE,
        related_name="trust_events",
    )

    delta = models.SmallIntegerField()
    reason = models.CharField(max_length=255)

    created_at = models.DateTimeField(auto_now_add=True)
