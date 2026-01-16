class Place {
  final String name;
  final double latitude;
  final double longitude;
  final String? street;
  final String? city;
  final String? region;
  final String? country;

  Place({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.street,
    this.city,
    this.region,
    this.country,
  });

  String get formattedAddress {
    final address = [
      street,
      city,
      region,
      country,
    ]
        .where((p) => p != null && p.trim().isNotEmpty)
        .join(', ');

    return address.isNotEmpty ? address : name;
  }

  Map<String, dynamic> toPayload() => {
    "latitude": latitude,
    "longitude": longitude,
    "address": formattedAddress,
  };


  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      name: json["name"] ?? "",
      latitude: (json["latitude"] ?? 0).toDouble(),
      longitude: (json["longitude"] ?? 0).toDouble(),
      street: json["street"],
      city: json["city"],
      region: json["region"],
      country: json["country"],
    );
  }
}

enum LocationMode {
  device,
  static,
}
