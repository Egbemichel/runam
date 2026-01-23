# Import necessary modules and settings
from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import models

# Get the user model dynamically to support custom user models
User = get_user_model()

# Model to track trust score changes for a user
class TrustScoreEvent(models.Model):
    # The user whose trust score is being updated
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,  # Delete trust score events if the user is deleted
        related_name="trust_events",  # Related name for reverse relation
    )

    # The change in trust score (positive or negative)
    delta = models.SmallIntegerField()

    # Reason for the trust score change
    reason = models.CharField(max_length=255)

    # Timestamp when the trust score event was created
    created_at = models.DateTimeField(auto_now_add=True)

# Model to represent a rating given by one user to another for a specific errand
class Rating(models.Model):
    # The errand associated with the rating
    errand = models.ForeignKey('errands.Errand', on_delete=models.CASCADE, related_name="ratings")

    # The user who is giving the rating
    rater = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="given_ratings")

    # The user who is receiving the rating
    ratee = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="received_ratings")

    # The score given in the rating (e.g., 1-5 stars)
    score = models.PositiveSmallIntegerField()

    # Optional comment provided by the rater
    comment = models.TextField(blank=True, null=True)

    # Timestamp when the rating was created
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        # Ensure that a user can only rate another user once per errand
        unique_together = ("errand", "rater", "ratee")

    def __str__(self):
        # String representation of the rating
        return f"Rating {self.score} for {self.ratee} by {self.rater} on errand {self.errand_id}"
