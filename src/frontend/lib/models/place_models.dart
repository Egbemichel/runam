class Place {
  final String name;
  final double lat;
  final double lng;
  final String? street;
  final String? city;
  final String? region;
  final String? country;

  Place({
    required this.name,
    required this.lat,
    required this.lng,
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
    "name": name,
    "latitude": lat,
    "longitude": lng,
    "street": street,
    "city": city,
    "region": region,
    "country": country,
  };

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      name: json["name"] ?? "",
      lat: (json["latitude"] ?? 0).toDouble(),
      lng: (json["longitude"] ?? 0).toDouble(),
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
