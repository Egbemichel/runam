import 'dart:async';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place_models.dart';
import '../services/location_service.dart';
import 'auth_controller.dart';

class LocationController extends GetxController {
  final locationMode = LocationMode.device.obs;

  final currentPosition = Rxn<Position>();
  final staticPlace = Rxn<Place>();

  StreamSubscription<Position>? _positionStream;

  final LocationService _locationService = LocationService();

  @override
  void onInit() {
    super.onInit();

    final auth = Get.find<AuthController>();

    ever(auth.user, (_) {
      if (auth.userRoles.contains("Runner")) {
        locationMode.value = LocationMode.device;
      }
    });
  }


  void switchToDevice() {
    locationMode.value = LocationMode.device;
    staticPlace.value = null;
    startDeviceTracking();
  }

  void switchToStatic(Place place) {
    locationMode.value = LocationMode.static;
    staticPlace.value = place;
    stopDeviceTracking();
  }

  Future<void> startDeviceTracking() async {
    stopDeviceTracking();

    _positionStream = await _locationService.positionStream(
          (position) {
        currentPosition.value = position;
      },
    );
  }

  void stopDeviceTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  Map<String, dynamic> toPayload() {
    if (locationMode.value == LocationMode.device &&
        currentPosition.value != null) {
      return {
        "mode": "DEVICE",
        "lat": currentPosition.value!.latitude,
        "lng": currentPosition.value!.longitude,
      };
    }

    if (locationMode.value == LocationMode.static &&
        staticPlace.value != null) {
      return {
        "mode": "STATIC",
        "lat": staticPlace.value!.lat,
        "lng": staticPlace.value!.lng,
        "label": staticPlace.value!.name,
      };
    }

    return {};
  }
}
