import '../../../models/place_models.dart';

class ErrandDraft {
  String? id;
  String? type;
  String? instructions;
  String? speed;
  String? paymentMethod;
  Place? goTo;
  Place? returnTo;

  bool get isComplete =>
      type != null &&
      goTo != null &&
      instructions != null &&
      speed != null &&
      paymentMethod != null &&
      (type != 'ROUND_TRIP' || returnTo != null);

  Map<String, dynamic> toJson() => {
    "id": id,
    "type": type,
    "instructions": instructions,
    "speed": speed,
    "payment_method": paymentMethod,
    "go_to": goTo?.toPayload(),
    "return_to": returnTo?.toPayload(),
  };

  static ErrandDraft fromJson(Map<String, dynamic> json) {
    return ErrandDraft()
      ..id = json["id"]
      ..type = json["type"]
      ..instructions = json["instructions"]
      ..speed = json["speed"]
      ..paymentMethod = json["payment_method"]
      ..goTo = json["go_to"] != null ? Place.fromJson(json["go_to"]) : null
      ..returnTo = json["return_to"] != null ? Place.fromJson(json["return_to"]) : null;
  }
}
