class ErrandLocation {
  final String placeId;
  final String address;
  final double lat;
  final double lng;

  ErrandLocation({
    required this.placeId,
    required this.address,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
    "placeId": placeId,
    "address": address,
    "latitude": lat,
    "longitude": lng,
  };

  factory ErrandLocation.fromJson(Map<String, dynamic> json) {
    return ErrandLocation(
      placeId: json["placeId"] ?? "",
      address: json["address"] ?? "",
      lat: (json["latitude"] ?? 0).toDouble(),
      lng: (json["longitude"] ?? 0).toDouble(),
    );
  }
}
