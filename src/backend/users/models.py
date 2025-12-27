from django.db import models
from django.contrib.auth.models import AbstractUser

class User(AbstractUser):
    # URL for the Google profile picture or other avatars
    avatar = models.URLField(blank=True, null=True)

    # Add other custom fields here if needed
    # e.g., phone_number = models.CharField(max_length=20, blank=True, null=True)
