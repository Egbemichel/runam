import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../services/graphql_client.dart';

/// Top-level function for handling background messages
/// Must be a top-level function, not a class method
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📬 [Notification] Background message received: ${message.messageId}');
  print('📬 [Notification] Title: ${message.notification?.title}');
  print('📬 [Notification] Body: ${message.notification?.body}');
  print('📬 [Notification] Data: ${message.data}');
}

class NotificationService extends GetxService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Initialize Firebase Cloud Messaging
  Future<void> initialize() async {
    print('🔔 [Notification] Initializing FCM...');

    try {
      // Request permission for iOS
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('🔔 [Notification] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ [Notification] User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('⚠️ [Notification] User granted provisional permission');
      } else {
        print('❌ [Notification] User declined or has not accepted permission');
        return;
      }

      // Get FCM token
      await _getFCMToken();

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);

      // Check if app was opened from a terminated state via notification
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessageTap(initialMessage);
      }

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      print('✅ [Notification] FCM initialized successfully');
    } catch (e) {
      print('❌ [Notification] Error initializing FCM: $e');
    }
  }

  /// Get FCM token and register it with backend
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        print('🔑 [Notification] FCM Token: ${_fcmToken!.substring(0, 20)}...');
        await _registerTokenWithBackend(_fcmToken!);
      } else {
        print('⚠️ [Notification] FCM token is null');
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('🔄 [Notification] FCM token refreshed');
        _fcmToken = newToken;
        _registerTokenWithBackend(newToken);
      });
    } catch (e) {
      print('❌ [Notification] Error getting FCM token: $e');
    }
  }

  /// Register FCM token with backend via GraphQL
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      const String mutation = '''
        mutation RegisterFCMToken(\$token: String!, \$deviceId: String) {
          registerFcmToken(token: \$token, deviceId: \$deviceId) {
            ok
            message
          }
        }
      ''';

      final QueryResult result = await GraphQLClientInstance.client.mutate(
        MutationOptions(
          document: gql(mutation),
          variables: {
            'token': token,
            'deviceId': null, // You can add device ID tracking if needed
          },
        ),
      );

      if (result.hasException) {
        print('❌ [Notification] Error registering token: ${result.exception}');
      } else {
        final data = result.data?['registerFcmToken'];
        if (data?['ok'] == true) {
          print('✅ [Notification] Token registered: ${data['message']}');
        } else {
          print('⚠️ [Notification] Token registration failed: ${data?['message']}');
        }
      }
    } catch (e) {
      print('❌ [Notification] Exception registering token: $e');
    }
  }

  /// Handle foreground messages (when app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    print('📬 [Notification] Foreground message received');
    print('📬 [Notification] Title: ${message.notification?.title}');
    print('📬 [Notification] Body: ${message.notification?.body}');
    print('📬 [Notification] Data: ${message.data}');

    // You can show an in-app notification here
    // For example, using GetX snackbar or a custom notification widget
    if (message.notification != null) {
      Get.snackbar(
        message.notification!.title ?? 'Notification',
        message.notification!.body ?? '',
        duration: const Duration(seconds: 4),
      );
    }

    // Handle data payload if needed
    if (message.data.isNotEmpty) {
      _handleNotificationData(message.data);
    }
  }

  /// Handle notification tap when app is in background
  void _handleBackgroundMessageTap(RemoteMessage message) {
    print('📬 [Notification] App opened from notification');
    print('📬 [Notification] Title: ${message.notification?.title}');
    print('📬 [Notification] Body: ${message.notification?.body}');
    print('📬 [Notification] Data: ${message.data}');

    // Handle navigation based on notification data
    if (message.data.isNotEmpty) {
      _handleNotificationData(message.data);
    }
  }

  /// Handle notification data payload
  void _handleNotificationData(Map<String, dynamic> data) {
    print('📬 [Notification] Handling data: $data');

    // Example: Navigate to specific screen based on notification type
    final type = data['type'];
    final errandId = data['errandId'];

    switch (type) {
      case 'errand_accepted':
        // Navigate to errand details
        if (errandId != null) {
          // Get.toNamed('/errand/$errandId');
          print('📬 [Notification] Navigate to errand: $errandId');
        }
        break;
      case 'errand_completed':
        // Navigate to errand details
        if (errandId != null) {
          // Get.toNamed('/errand/$errandId');
          print('📬 [Notification] Navigate to completed errand: $errandId');
        }
        break;
      default:
        print('📬 [Notification] Unknown notification type: $type');
    }
  }

  /// Unregister FCM token from backend
  Future<void> unregisterToken() async {
    if (_fcmToken == null) return;

    try {
      const String mutation = '''
        mutation UnregisterFCMToken(\$token: String!) {
          unregisterFcmToken(token: \$token) {
            ok
            message
          }
        }
      ''';

      final QueryResult result = await GraphQLClientInstance.client.mutate(
        MutationOptions(
          document: gql(mutation),
          variables: {
            'token': _fcmToken!,
          },
        ),
      );

      if (result.hasException) {
        print('❌ [Notification] Error unregistering token: ${result.exception}');
      } else {
        final data = result.data?['unregisterFcmToken'];
        if (data?['ok'] == true) {
          print('✅ [Notification] Token unregistered: ${data['message']}');
        }
      }
    } catch (e) {
      print('❌ [Notification] Exception unregistering token: $e');
    }
  }
}
