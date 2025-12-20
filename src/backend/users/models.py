from django.db import models
from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    # Add custom fields here if needed (e.g., profile_picture_url)
    pass
