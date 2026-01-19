import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import '../services/auth_service.dart';
import '../models/place_models.dart';
import '../services/location_service.dart';
import 'auth_controller.dart';

class LocationController extends GetxController {
  static const String _tag = '📍 [LocationController]';
  static const String _modeKey = 'location_mode';
  static const String _staticPlaceKey = 'static_place';

  final _storage = GetStorage();

  final locationMode = LocationMode.device.obs;
  final currentPosition = Rxn<Position>();
  final staticPlace = Rxn<Place>();

  StreamSubscription<Position>? _positionStream;
  Position? _lastSentPosition;
  DateTime? _lastSentAt;
  bool _sendingLocation = false;
  int _authRetries = 0; // retry counter for waiting AuthService registration
  bool _triedAutoRegister = false;

  // Configuration: how often to push (min interval) and min distance to trigger
  static const int _locationPushIntervalSeconds = 25; // min seconds between pushes
  static const double _minDistanceMeters = 20.0; // only push if moved > 20m

  final LocationService _locationService = LocationService();

  @override
  void onInit() {
    super.onInit();
    debugPrint('$_tag Initializing LocationController...');

    // Load persisted location mode and static place
    _loadPersistedState();

    final auth = Get.find<AuthController>();

    ever(auth.user, (_) {
      if (auth.userRoles.contains("RUNNER")) {
        debugPrint('$_tag User is a RUNNER - forcing device mode');
        locationMode.value = LocationMode.device;
        _persistState();
      }
    });

    // Log whenever location mode changes
    ever(locationMode, (mode) {
      debugPrint('$_tag Location mode changed to: ${mode.name}');
    });

    // Log whenever position updates
    ever(currentPosition, (pos) {
      if (pos != null) {
        debugPrint('$_tag Device position updated: latitude=${pos.latitude}, longitude=${pos.longitude}');
        // Attempt to push to backend (throttled)
        _onPositionUpdated(pos);
      }
    });

    // Log whenever static place changes
    ever(staticPlace, (place) {
      if (place != null) {
        debugPrint('$_tag Static place set: ${place.name} (${place.latitude}, ${place.longitude})');
      } else {
        debugPrint('$_tag Static place cleared');
      }
    });
  }

  /// Load persisted location mode and static place from storage
  void _loadPersistedState() {
    debugPrint('$_tag Loading persisted state from storage...');

    // Load location mode
    final savedMode = _storage.read<String>(_modeKey);
    if (savedMode != null) {
      locationMode.value = savedMode == 'static' ? LocationMode.static : LocationMode.device;
      debugPrint('$_tag Loaded location mode: ${locationMode.value.name}');
    } else {
      debugPrint('$_tag No saved location mode, defaulting to device');
    }

    // Load static place if exists
    final savedPlace = _storage.read<String>(_staticPlaceKey);
    if (savedPlace != null) {
      try {
        final placeJson = jsonDecode(savedPlace);
        staticPlace.value = Place.fromJson(placeJson);
        debugPrint('$_tag Loaded static place: ${staticPlace.value?.name}');
      } catch (e) {
        debugPrint('$_tag Error loading static place: $e');
      }
    } else {
      debugPrint('$_tag No saved static place');
    }

    // Start tracking if in device mode
    if (locationMode.value == LocationMode.device) {
      debugPrint('$_tag Starting device tracking (restored from persisted state)');
      startDeviceTracking();
    }
  }

  /// Persist current state to storage
  void _persistState() {
    debugPrint('$_tag Persisting state to storage...');

    // Save location mode
    _storage.write(_modeKey, locationMode.value == LocationMode.static ? 'static' : 'device');
    debugPrint('$_tag Saved location mode: ${locationMode.value.name}');

    // Save static place if set
    if (staticPlace.value != null) {
      final placeJson = jsonEncode(staticPlace.value!.toPayload());
      _storage.write(_staticPlaceKey, placeJson);
      debugPrint('$_tag Saved static place: ${staticPlace.value!.name}');
    } else {
      _storage.remove(_staticPlaceKey);
      debugPrint('$_tag Cleared static place from storage');
    }
  }

  void switchToDevice() {
    debugPrint('$_tag === SWITCHING TO DEVICE MODE ===');
    locationMode.value = LocationMode.device;
    staticPlace.value = null;
    _persistState();
    startDeviceTracking();
    debugPrint('$_tag Device mode activated, GPS tracking started');
  }

  /// Switch to static mode with a selected place
  void switchToStatic(Place place) {
    debugPrint('$_tag === SWITCHING TO STATIC MODE ===');
    debugPrint('$_tag Selected place: ${place.name}');
    debugPrint('$_tag Coordinates: lat=${place.latitude}, lng=${place.longitude}');
    locationMode.value = LocationMode.static;
    staticPlace.value = place;
    stopDeviceTracking();
    _persistState();
    debugPrint('$_tag Static mode activated, GPS tracking stopped');
  }

  /// Switch to static mode without a place (user will select later)
  /// This stops GPS tracking immediately
  void prepareStaticMode() {
    debugPrint('$_tag === PREPARING STATIC MODE ===');
    debugPrint('$_tag Stopping GPS tracking, waiting for user to select location');
    locationMode.value = LocationMode.static;
    stopDeviceTracking();
    _persistState();
    debugPrint('$_tag Static mode prepared, GPS stopped');
  }

  Future<void> startDeviceTracking() async {
    debugPrint('$_tag Starting device tracking...');
    stopDeviceTracking();

    _positionStream = await _locationService.positionStream(
      (position) {
        currentPosition.value = position;
        debugPrint('$_tag GPS update: lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}m');
      },
    );
    debugPrint('$_tag Device tracking started successfully');
  }

  // Called whenever currentPosition updates. Decides whether to push to backend.
  void _onPositionUpdated(Position pos) {
    // Only for DEVICE mode
    if (locationMode.value != LocationMode.device) return;

    final now = DateTime.now();

    // If never sent before, send immediately
    if (_lastSentAt == null || _lastSentPosition == null) {
      _sendLocationToServer(pos);
      return;
    }

    final elapsed = now.difference(_lastSentAt!);
    if (elapsed.inSeconds >= _locationPushIntervalSeconds) {
      // enough time passed, but check distance too
      final dist = Geolocator.distanceBetween(
        _lastSentPosition!.latitude,
        _lastSentPosition!.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (dist >= _minDistanceMeters) {
        _sendLocationToServer(pos);
      } else {
        debugPrint('$_tag Skipping push: moved ${dist.toStringAsFixed(1)}m which is < $_minDistanceMeters m and interval satisfied');
      }
    } else {
      // not enough time passed, only send if moved a lot
      final dist = Geolocator.distanceBetween(
        _lastSentPosition!.latitude,
        _lastSentPosition!.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (dist >= _minDistanceMeters * 3) {
        debugPrint('$_tag Force sending due to large movement: ${dist.toStringAsFixed(1)}m');
        _sendLocationToServer(pos);
      }
    }
  }

  Future<void> _sendLocationToServer(Position pos) async {
    if (_sendingLocation) {
      debugPrint('$_tag Location push already in progress; skipping');
      return;
    }
    _sendingLocation = true;

    final payload = {
      'mode': 'DEVICE',
      'latitude': pos.latitude,
      'longitude': pos.longitude,
    };

    debugPrint('$_tag Pushing location to backend: $payload');
    try {
      // If AuthService hasn't been registered yet, wait a bit and retry a few times.
      if (!Get.isRegistered<AuthService>()) {
        debugPrint('$_tag AuthService not registered yet.');

        // Try one-time auto-registration to handle init order issues
        if (!_triedAutoRegister) {
          debugPrint('$_tag Attempting one-time auto-registration of AuthService...');
          try {
            Get.put(AuthService());
            debugPrint('$_tag Auto-registered AuthService via Get.put(AuthService())');
          } catch (e) {
            debugPrint('$_tag Auto-registration of AuthService failed: $e');
          }
          _triedAutoRegister = true;
        }

        // If still not registered, schedule retry as before
        if (!Get.isRegistered<AuthService>()) {
          debugPrint('$_tag Scheduling retry... (attempt ${_authRetries + 1}/5)');
          _sendingLocation = false; // allow subsequent attempts
          if (_authRetries < 5) {
            _authRetries++;
            Future.delayed(const Duration(seconds: 2), () => _sendLocationToServer(pos));
          } else {
            debugPrint('$_tag Giving up sending location after $_authRetries attempts because AuthService is not available.');
            _authRetries = 0;
          }
          return;
        }
      }

      // Reset retry counter when AuthService is available
      _authRetries = 0;

      final authService = Get.find<AuthService>();
      final success = await authService.updateLocation(
        mode: 'DEVICE',
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      if (success) {
        _lastSentAt = DateTime.now();
        _lastSentPosition = pos;
        debugPrint('$_tag Location push succeeded at $_lastSentAt');
      } else {
        debugPrint('$_tag Location push failed (server returned failure)');
      }
    } catch (e, st) {
      debugPrint('$_tag Exception while pushing location: $e');
      debugPrint(st.toString());
    } finally {
      _sendingLocation = false;
    }
  }

  void stopDeviceTracking() {
    if (_positionStream != null) {
      debugPrint('$_tag Stopping device tracking...');
      _positionStream?.cancel();
      _positionStream = null;
      debugPrint('$_tag Device tracking stopped');
    }
    // reset last sent
    _lastSentAt = null;
    _lastSentPosition = null;
  }

  Map<String, dynamic> toPayload() {
    debugPrint('$_tag Building location payload...');

    if (locationMode.value == LocationMode.device && currentPosition.value != null) {
      final lat = currentPosition.value!.latitude;
      final lng = currentPosition.value!.longitude;

      // lat/lng are non-nullable doubles from Position

      final payload = {
        "mode": "DEVICE",
        "latitude": lat,
        "longitude": lng,
      };
      debugPrint('$_tag Payload (device): $payload');
      return payload;
    }

    if (locationMode.value == LocationMode.static && staticPlace.value != null) {
      final lat = staticPlace.value!.latitude;
      final lng = staticPlace.value!.longitude;

      // lat/lng are non-nullable doubles on Place

      final payload = {
        "mode": "STATIC",
        "latitude": lat,
        "longitude": lng,
        "address": staticPlace.value!.name,
      };
      debugPrint('$_tag Payload (static): $payload');
      return payload;
    }

    debugPrint('$_tag Payload: empty (no valid location)');
    return {};
  }


  @override
  void onClose() {
    debugPrint('$_tag Disposing LocationController...');
    stopDeviceTracking();
    super.onClose();
  }
}
