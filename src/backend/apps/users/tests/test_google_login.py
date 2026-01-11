import pytest
from allauth.socialaccount.models import SocialAccount
from apps.users.tests.helpers import mock_google_login, get_user, get_social_account
from graphene_django.utils.testing import graphql_query
from django.contrib.auth import get_user_model

User = get_user_model()

pytestmark = pytest.mark.django_db

def test_google_login_creates_user(client, mock_google_login):
    mutation = """
        mutation VerifyGoogleToken($idToken: String!) {
            verifyGoogleToken(idToken: $idToken) {
                access
                user { id email name avatar trustScore roles { name } }
            }
        }
    """
    variables = {"idToken": "fake-google-id-token"}

    response = graphql_query(mutation, variables=variables, client=client)
    data = response.json()["data"]["verifyGoogleToken"]
    user = get_user()
    social = get_social_account(User)

    # JWT returned
    assert data["access"] is not None
    # User fields
    assert user.name == "Test User"
    assert user.avatar == "https://example.com/avatar.png"
    assert user.trust_score == 60
    assert user.roles.filter(name="BUYER").exists()
    # Social account
    assert social.provider == "google"
    assert social.uid == "google-unique-id-123"

def test_google_login_idempotent(client, mock_google_login):
    mutation = """
        mutation VerifyGoogleToken($idToken: String!) {
            verifyGoogleToken(idToken: $idToken) { access user { email } }
        }
    """
    variables = {"idToken": "fake-google-id-token"}

    # First login
    graphql_query(mutation, variables=variables, client=client)
    # Second login
    graphql_query(mutation, variables=variables, client=client)

    user = get_user()
    assert User.objects.count() == 1
    assert user.roles.filter(name="BUYER").count() == 1
    assert SocialAccount.objects.filter(user=user, provider="google").count() == 1
