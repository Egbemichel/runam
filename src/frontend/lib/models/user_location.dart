class UserLocation {
  final String id;
  final double latitude;
  final double longitude;
  final String label;
  final String type;
  final bool isActive;

  UserLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.type,
    required this.isActive,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    return UserLocation(
      id: json['id'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      label: json['label'] ?? '',
      type: json['type'] ?? '',
      isActive: json['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'label': label,
      'type': type,
      'isActive': isActive,
    };
  }

  @override
  String toString() {
    return 'UserLocation(id: $id, label: $label, lat: $latitude, lng: $longitude, type: $type, isActive: $isActive)';
  }
}

