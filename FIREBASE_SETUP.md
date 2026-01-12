# Firebase Cloud Messaging Setup Guide

This guide will help you set up Firebase Cloud Messaging (FCM) for push notifications in the RunAm application.

## Prerequisites

1. A Firebase project (create one at https://console.firebase.google.com/)
2. Flutter CLI installed
3. Firebase CLI installed (optional, for easier setup)

## Backend Setup

### 1. Install Python Dependencies

```bash
cd src/backend
pip install -r requirements.txt
```

This will install `firebase-admin==6.5.0`.

### 2. Get Firebase Service Account Credentials

1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate New Private Key"
3. Save the JSON file securely (e.g., `firebase-credentials.json`)

### 3. Configure Environment Variables

Add one of the following to your `.env` file in `src/backend/`:

**Option 1: Path to credentials file**
```env
FIREBASE_CREDENTIALS_PATH=/path/to/firebase-credentials.json
```

**Option 2: JSON string (for production/deployment)**
```env
FIREBASE_CREDENTIALS_JSON={"type":"service_account","project_id":"..."}
```

### 4. Run Database Migration

```bash
cd src/backend
python manage.py makemigrations users
python manage.py migrate
```

This creates the `FCMToken` table to store user device tokens.

## Frontend Setup

### 1. Install Flutter Dependencies

```bash
cd src/frontend
flutter pub get
```

This installs `firebase_core` and `firebase_messaging`.

### 2. Configure Firebase for Flutter

#### Option A: Using FlutterFire CLI (Recommended)

```bash
cd src/frontend
flutterfire configure
```

This will:
- Detect your Firebase projects
- Generate `firebase_options.dart` automatically
- Configure Android and iOS apps

#### Option B: Manual Setup

1. **Android Setup:**
   - Download `google-services.json` from Firebase Console
   - Place it in `src/frontend/android/app/`
   - Update `android/build.gradle`:
     ```gradle
     dependencies {
         classpath 'com.google.gms:google-services:4.4.0'
     }
     ```
   - Update `android/app/build.gradle`:
     ```gradle
     apply plugin: 'com.google.gms.google-services'
     ```

2. **iOS Setup:**
   - Download `GoogleService-Info.plist` from Firebase Console
   - Place it in `src/frontend/ios/Runner/`
   - Open `ios/Runner.xcworkspace` in Xcode
   - Add the file to the Runner target

3. **Create `firebase_options.dart`:**
   ```dart
   import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
   import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

   class DefaultFirebaseOptions {
     static FirebaseOptions get currentPlatform {
       if (defaultTargetPlatform == TargetPlatform.android) {
         return android;
       } else if (defaultTargetPlatform == TargetPlatform.iOS) {
         return ios;
       }
       throw UnsupportedError('Unsupported platform');
     }

     static const FirebaseOptions android = FirebaseOptions(
       apiKey: 'YOUR_ANDROID_API_KEY',
       appId: 'YOUR_ANDROID_APP_ID',
       messagingSenderId: 'YOUR_SENDER_ID',
       projectId: 'YOUR_PROJECT_ID',
     );

     static const FirebaseOptions ios = FirebaseOptions(
       apiKey: 'YOUR_IOS_API_KEY',
       appId: 'YOUR_IOS_APP_ID',
       messagingSenderId: 'YOUR_SENDER_ID',
       projectId: 'YOUR_PROJECT_ID',
     );
   }
   ```

   Place this file in `src/frontend/lib/firebase_options.dart` and update `main.dart`:
   ```dart
   import 'firebase_options.dart';
   
   await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   ```

### 3. Android Notification Channel Setup

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <application>
        <!-- ... existing code ... -->
        
        <!-- FCM Notification Channel -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="default" />
    </application>
</manifest>
```

Create notification channel in `android/app/src/main/kotlin/.../MainActivity.kt`:

```kotlin
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "default",
                "Default Notifications",
                NotificationManager.IMPORTANCE_HIGH
            )
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}
```

### 4. iOS Setup

Add to `ios/Runner/Info.plist`:

```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

Enable Push Notifications capability in Xcode:
1. Open `ios/Runner.xcworkspace`
2. Select Runner target
3. Signing & Capabilities → + Capability → Push Notifications

## Testing

### Backend Test

```python
from apps.users.notifications import send_notification_to_user
from django.contrib.auth import get_user_model

User = get_user_model()
user = User.objects.first()

send_notification_to_user(
    user=user,
    title="Test Notification",
    body="This is a test notification",
    data={"type": "test", "errandId": "123"}
)
```

### Frontend Test

The notification service automatically:
- Requests permissions on app start
- Registers FCM token with backend
- Handles foreground, background, and terminated state notifications

Check logs for:
- `✅ [Notification] FCM initialized successfully`
- `✅ [Notification] Token registered: ...`

## Usage Examples

### Sending Notifications from Backend

```python
from apps.users.notifications import send_notification_to_user

# When errand is accepted
send_notification_to_user(
    user=errand.user,
    title="Errand Accepted",
    body=f"Your errand has been accepted by {runner.name}",
    data={
        "type": "errand_accepted",
        "errandId": str(errand.id),
    }
)

# When errand is completed
send_notification_to_user(
    user=errand.user,
    title="Errand Completed",
    body="Your errand has been completed successfully",
    data={
        "type": "errand_completed",
        "errandId": str(errand.id),
    }
)
```

### Handling Notifications in Frontend

The `NotificationService` automatically handles:
- **Foreground**: Shows snackbar notification
- **Background**: Logs notification (can be extended to show local notification)
- **Terminated**: Handles when app is opened from notification

To customize navigation, update `_handleNotificationData` in `notification_service.dart`.

## Troubleshooting

### Backend Issues

- **"Firebase credentials not found"**: Check `FIREBASE_CREDENTIALS_PATH` or `FIREBASE_CREDENTIALS_JSON` in `.env`
- **"Permission denied"**: Ensure service account has "Firebase Cloud Messaging API Admin" role

### Frontend Issues

- **Token not registering**: Check GraphQL client is authenticated and backend is accessible
- **Notifications not received**: 
  - Verify FCM token is registered in backend database
  - Check device has internet connection
  - Verify Firebase project configuration matches app

### Common Errors

- **iOS**: Ensure Push Notifications capability is enabled
- **Android**: Check `google-services.json` is in correct location
- **Permissions**: User must grant notification permissions

## Security Notes

1. **Never commit** `firebase-credentials.json` or `google-services.json` to version control
2. Add to `.gitignore`:
   ```
   firebase-credentials.json
   google-services.json
   GoogleService-Info.plist
   firebase_options.dart
   ```
3. Use environment variables for production credentials
4. Rotate service account keys periodically

## Next Steps

1. Integrate notification sending in errand status changes
2. Add notification preferences/settings
3. Implement notification history/logs
4. Add rich notifications with images/actions
