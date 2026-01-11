import pytest
from unittest.mock import patch
from apps.roles.models import Role
from allauth.socialaccount.models import SocialAccount
from django.contrib.auth import get_user_model

User = get_user_model()

# Default mock Google payload
DEFAULT_GOOGLE_PAYLOAD = {
    "email": "testuser@gmail.com",
    "name": "Test User",
    "given_name": "Test",
    "family_name": "User",
    "picture": "https://example.com/avatar.png",
    "sub": "google-unique-id-123",
}

@pytest.fixture
def mock_google_login():
    """Patch verify_google_token to return a mock Google payload."""
    with patch("apps.users.schema.verify_google_token") as mock_verify:
        mock_verify.return_value = DEFAULT_GOOGLE_PAYLOAD
        # Ensure default Role exists
        Role.objects.get_or_create(name=Role.BUYER)
        yield mock_verify

def get_user():
    """Return the user created by mock Google login."""
    return User.objects.get(email=DEFAULT_GOOGLE_PAYLOAD["email"])

def get_social_account(user=None):
    user = user or get_user()
    return SocialAccount.objects.get(user=user)
