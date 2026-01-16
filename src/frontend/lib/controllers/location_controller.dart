import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
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

  void stopDeviceTracking() {
    if (_positionStream != null) {
      debugPrint('$_tag Stopping device tracking...');
      _positionStream?.cancel();
      _positionStream = null;
      debugPrint('$_tag Device tracking stopped');
    }
  }

  Map<String, dynamic> toPayload() {
    debugPrint('$_tag Building location payload...');

    if (locationMode.value == LocationMode.device && currentPosition.value != null) {
      final lat = currentPosition.value!.latitude;
      final lng = currentPosition.value!.longitude;

      if (lat == null || lng == null) {
        debugPrint('❌ [LocationController] Current position has null coordinates');
        return {};
      }

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

      if (lat == null || lng == null) {
        debugPrint('❌ [LocationController] Static place has null coordinates');
        return {};
      }

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

