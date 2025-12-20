from google.oauth2 import id_token
from google.auth.transport import requests
from django.conf import settings
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model

User = get_user_model()

@api_view(['POST'])
def google_auth(request):
    token = request.data.get('id_token')

    try:
        idinfo = id_token.verify_oauth2_token(
            token,
            requests.Request(),
            settings.GOOGLE_CLIENT_ID
        )

        email = idinfo['email']
        name = idinfo.get('name', '')

        user, created = User.objects.get_or_create(
            email=email,
            defaults={'username': email, 'first_name': name}
        )

        refresh = RefreshToken.for_user(user)

        return Response({
            'access': str(refresh.access_token),
            'refresh': str(refresh)
        })

    except ValueError:
        return Response({'error': 'Invalid token'}, status=400)
