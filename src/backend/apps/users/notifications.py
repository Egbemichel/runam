"""
Firebase Cloud Messaging notification service
"""
import os
import json
from typing import List, Optional, Dict, Any
from django.conf import settings
from django.contrib.auth import get_user_model
from firebase_admin import messaging, credentials, initialize_app, get_app
from firebase_admin.exceptions import FirebaseError

User = get_user_model()

# Initialize Firebase Admin SDK
_firebase_app = None

def get_firebase_app():
    """Initialize Firebase Admin SDK if not already initialized"""
    global _firebase_app
    if _firebase_app is None:
        try:
            # Try to get existing app first
            _firebase_app = get_app()
        except ValueError:
            # App doesn't exist, initialize it
            firebase_credentials_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
            if firebase_credentials_path and os.path.exists(firebase_credentials_path):
                cred = credentials.Certificate(firebase_credentials_path)
                _firebase_app = initialize_app(cred)
            else:
                # Try using JSON string from environment variable
                firebase_credentials_json = os.getenv('FIREBASE_CREDENTIALS_JSON')
                if firebase_credentials_json:
                    cred_dict = json.loads(firebase_credentials_json)
                    cred = credentials.Certificate(cred_dict)
                    _firebase_app = initialize_app(cred)
                else:
                    raise ValueError(
                        "Firebase credentials not found. Set FIREBASE_CREDENTIALS_PATH or "
                        "FIREBASE_CREDENTIALS_JSON environment variable."
                    )
    return _firebase_app


def send_notification_to_user(
    user: User,
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None,
    image_url: Optional[str] = None,
) -> bool:
    """
    Send a push notification to all active FCM tokens for a user
    
    Args:
        user: The user to send notification to
        title: Notification title
        body: Notification body text
        data: Optional data payload (dict)
        image_url: Optional image URL for notification
        
    Returns:
        bool: True if at least one notification was sent successfully
    """
    from .models import FCMToken
    
    tokens = FCMToken.objects.filter(user=user, is_active=True).values_list('token', flat=True)
    
    if not tokens:
        return False
    
    try:
        get_firebase_app()
    except ValueError as e:
        print(f"Firebase initialization error: {e}")
        return False
    
    # Build notification payload
    notification = messaging.Notification(
        title=title,
        body=body,
        image=image_url,
    )
    
    # Build message
    message = messaging.MulticastMessage(
        notification=notification,
        data=data or {},
        tokens=list(tokens),
        android=messaging.AndroidConfig(
            priority='high',
            notification=messaging.AndroidNotification(
                sound='default',
                channel_id='default',
            ),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    sound='default',
                    badge=1,
                ),
            ),
        ),
    )
    
    try:
        response = messaging.send_multicast(message)
        print(f"Successfully sent {response.success_count} notifications to {user.email}")
        
        # Deactivate failed tokens
        if response.failure_count > 0:
            failed_tokens = []
            for idx, result in enumerate(response.responses):
                if not result.success:
                    failed_tokens.append(tokens[idx])
                    print(f"Failed to send to token: {result.exception}")
            
            if failed_tokens:
                FCMToken.objects.filter(token__in=failed_tokens).update(is_active=False)
        
        return response.success_count > 0
    except FirebaseError as e:
        print(f"Firebase error sending notification: {e}")
        return False
    except Exception as e:
        print(f"Unexpected error sending notification: {e}")
        return False


def send_notification_to_tokens(
    tokens: List[str],
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None,
    image_url: Optional[str] = None,
) -> bool:
    """
    Send a push notification to specific FCM tokens
    
    Args:
        tokens: List of FCM tokens
        title: Notification title
        body: Notification body text
        data: Optional data payload (dict)
        image_url: Optional image URL for notification
        
    Returns:
        bool: True if at least one notification was sent successfully
    """
    if not tokens:
        return False
    
    try:
        get_firebase_app()
    except ValueError as e:
        print(f"Firebase initialization error: {e}")
        return False
    
    notification = messaging.Notification(
        title=title,
        body=body,
        image=image_url,
    )
    
    message = messaging.MulticastMessage(
        notification=notification,
        data=data or {},
        tokens=tokens,
        android=messaging.AndroidConfig(
            priority='high',
            notification=messaging.AndroidNotification(
                sound='default',
                channel_id='default',
            ),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    sound='default',
                    badge=1,
                ),
            ),
        ),
    )
    
    try:
        response = messaging.send_multicast(message)
        print(f"Successfully sent {response.success_count} notifications")
        
        if response.failure_count > 0:
            for idx, result in enumerate(response.responses):
                if not result.success:
                    print(f"Failed to send to token: {result.exception}")
        
        return response.success_count > 0
    except FirebaseError as e:
        print(f"Firebase error sending notification: {e}")
        return False
    except Exception as e:
        print(f"Unexpected error sending notification: {e}")
        return False
