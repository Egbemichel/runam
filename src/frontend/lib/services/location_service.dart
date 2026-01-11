import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<StreamSubscription<Position>> positionStream(
      Function(Position) onData,
      ) async {
    await Geolocator.requestPermission();

    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(onData);
  }
}
