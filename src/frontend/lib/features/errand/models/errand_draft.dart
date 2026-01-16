import 'dart:convert';
import '../../../models/place_models.dart';

class ErrandTaskDraft {
  String description;
  int price;

  ErrandTaskDraft({required this.description, required this.price});

  Map<String, dynamic> toJson() => {
    'description': description,
    'price': price,
  };

  factory ErrandTaskDraft.fromJson(Map<String, dynamic> json) {
    return ErrandTaskDraft(
      description: json['description'] ?? '',
      price: json['price'] ?? 0,
    );
  }
}

class ErrandDraft {
  String? id;
  String? type; // "ONE_WAY" or "ROUND_TRIP"
  List<ErrandTaskDraft> tasks; // Replaces instructions
  String? speed;
  String? paymentMethod;
  Place? goTo;
  Place? returnTo;

  // Initialize with one empty task row by default to match the UI
  ErrandDraft({
    this.id,
    this.type = "ONE_WAY",
    List<ErrandTaskDraft>? tasks,
    this.speed = "10mins",
    this.paymentMethod,
    this.goTo,
    this.returnTo,
  }) : tasks = tasks ?? [ErrandTaskDraft(description: "", price: 0)];

  /// Validation logic updated for the new Task/Price structure
  bool get isComplete =>
      type != null &&
          goTo != null &&
          tasks.isNotEmpty &&
          // Ensure all tasks have a description and a valid price
          tasks.every((t) => t.description.trim().isNotEmpty && t.price > 0) &&
          speed != null &&
          paymentMethod != null &&
          (type != 'ROUND_TRIP' || returnTo != null);

  /// Converts the draft to a payload for the GraphQL mutation
  Map<String, dynamic> toJson() => {
    "id": id,
    "type": type,
    "tasks": tasks.map((t) => t.toJson()).toList(), //
    "speed": speed,
    "payment_method": paymentMethod,
    "go_to": goTo?.toPayload(),
    "return_to": returnTo?.toPayload(),
  };

  /// Parses a draft (e.g., from local storage/cache) back into the object
  static ErrandDraft fromJson(Map<String, dynamic> json) {
    var tasksFromJson = json['tasks'] as List?;
    List<ErrandTaskDraft> taskList = tasksFromJson != null
        ? tasksFromJson.map((t) => ErrandTaskDraft.fromJson(t)).toList()
        : [ErrandTaskDraft(description: "", price: 0)];

    return ErrandDraft(
      id: json["id"],
      type: json["type"],
      tasks: taskList,
      speed: json["speed"],
      paymentMethod: json["payment_method"],
      goTo: json["go_to"] != null ? Place.fromJson(json["go_to"]) : null,
      returnTo: json["return_to"] != null ? Place.fromJson(json["return_to"]) : null,
    );
  }
}