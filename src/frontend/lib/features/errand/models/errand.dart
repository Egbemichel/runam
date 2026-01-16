import 'dart:convert';

import '../../../models/place_models.dart';
import '../models/errand_draft.dart';

/// Enum for errand status categories
enum ErrandStatus {
  pending,    // Searching for runner, isOpen=true
  accepted,   // Runner accepted, in progress
  completed,  // Successfully completed
  expired,    // Time ran out, isOpen=false, no runner found
  cancelled,  // Cancelled by user
}

extension ErrandStatusExtension on ErrandStatus {
  String get label {
    switch (this) {
      case ErrandStatus.pending:
        return 'Pending';
      case ErrandStatus.accepted:
        return 'In Progress';
      case ErrandStatus.completed:
        return 'Completed';
      case ErrandStatus.expired:
        return 'Expired';
      case ErrandStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get description {
    switch (this) {
      case ErrandStatus.pending:
        return 'Searching for runner...';
      case ErrandStatus.accepted:
        return 'Runner on the way';
      case ErrandStatus.completed:
        return 'Errand completed';
      case ErrandStatus.expired:
        return 'No runner found';
      case ErrandStatus.cancelled:
        return 'Errand cancelled';
    }
  }

  static ErrandStatus fromString(String? status) {
    if (status == null) return ErrandStatus.pending;
    switch (status.toUpperCase()) {
      case 'PENDING':
        return ErrandStatus.pending;
      case 'ACCEPTED':
      case 'IN_PROGRESS':
        return ErrandStatus.accepted;
      case 'COMPLETED':
        return ErrandStatus.completed;
      case 'EXPIRED':
        return ErrandStatus.expired;
      case 'CANCELLED':
        return ErrandStatus.cancelled;
      default:
        return ErrandStatus.pending;
    }
  }

  String toApiString() {
    switch (this) {
      case ErrandStatus.pending:
        return 'PENDING';
      case ErrandStatus.accepted:
        return 'ACCEPTED';
      case ErrandStatus.completed:
        return 'COMPLETED';
      case ErrandStatus.expired:
        return 'EXPIRED';
      case ErrandStatus.cancelled:
        return 'CANCELLED';
    }
  }
}

/// Full Errand model for fetched errands
class Errand {
  final String id;
  final String type;
  final List<ErrandTaskDraft> tasks;
  final String speed;
  final String paymentMethod;
  final Place goTo;
  final Place? returnTo;
  final String? imageUrl;
  final ErrandStatus status;
  final bool isOpen;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? runnerId;
  final String? runnerName;
  final double? price;

  Errand({
    required this.id,
    required this.type,
    required this.tasks,
    required this.speed,
    required this.paymentMethod,
    required this.goTo,
    this.returnTo,
    this.imageUrl,
    required this.status,
    required this.isOpen,
    required this.createdAt,
    required this.expiresAt,
    this.runnerId,
    this.runnerName,
    this.price,
  });

  /// Check if the errand has expired based on current time
  bool get hasExpired => DateTime.now().isAfter(expiresAt);

  /// Time remaining until expiry
  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }


  /// Runner score (optional, default 0)
  double get runnerScore => 0.0; // replace with real data if available

  /// Time taken to complete the errand (optional, default 0)
  int get timeTaken {
    if (status == ErrandStatus.completed) {
      return expiresAt.difference(createdAt).inMinutes;
    }
    return 0;
  }

  /// Formatted createdAt string
  String get createdAtFormatted {
    return '${createdAt.day.toString().padLeft(2, '0')}/'
        '${createdAt.month.toString().padLeft(2, '0')}/'
        '${createdAt.year} '
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}';
  }


  /// Formatted time remaining string
  String get timeRemainingFormatted {
    final remaining = timeRemaining;
    if (remaining == Duration.zero) return 'Expired';

    if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
    } else {
      return '${remaining.inSeconds}s';
    }
  }

  /// Progress percentage (0.0 to 1.0) of time elapsed
  double get expiryProgress {
    final total = expiresAt.difference(createdAt).inSeconds;
    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  factory Errand.fromJson(Map<String, dynamic> json) {
    // helper to safely get a string value
    String safeString(dynamic v) => v == null ? '' : v.toString();

    // parse tasks
    final tasksList = (json['tasks'] as List<dynamic>?) ?? (json['task_list'] as List<dynamic>?) ?? [];

    return Errand(
      id: safeString(json['id']),
      type: safeString(json['type']),
      tasks: tasksList.map((t) => ErrandTaskDraft.fromJson(t as Map<String, dynamic>)).toList(),
      speed: safeString(json['speed']),
      paymentMethod: safeString(json['paymentMethod'] ?? json['payment_method']),
      goTo: _parsePlaceFromJson(json['goTo'] ?? json['go_to']),
      returnTo: (json['returnTo'] ?? json['return_to']) != null
          ? _parsePlaceFromJson(json['returnTo'] ?? json['return_to'])
          : null,
      imageUrl: json['imageUrl'] ?? json['image_url'],
      status: ErrandStatusExtension.fromString(safeString(json['status'])),
      isOpen: json['isOpen'] ?? json['is_open'] ?? false,
      createdAt: DateTime.tryParse(safeString(json['createdAt'] ?? json['created_at'])) ?? DateTime.now(),
      expiresAt: DateTime.tryParse(safeString(json['expiresAt'] ?? json['expires_at'])) ?? DateTime.now(),
      runnerId: json['runnerId'] ?? json['runner_id'] != null ? safeString(json['runnerId'] ?? json['runner_id']) : null,
      runnerName: json['runnerName'] ?? json['runner_name'] != null ? safeString(json['runnerName'] ?? json['runner_name']) : null,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
    );
  }

  static Place _parsePlaceFromJson(dynamic json) {
    // Handle nulls and stringified JSON
    if (json == null) {
      return Place(name: '', latitude: 0.0, longitude: 0.0);
    }

    Map<String, dynamic> map;
    if (json is String) {
      try {
        map = jsonDecode(json) as Map<String, dynamic>;
      } catch (_) {
        // Treat the string as the name/address
        return Place(name: json, latitude: 0.0, longitude: 0.0);
      }
    } else if (json is Map<String, dynamic>) {
      map = json;
    } else {
      // Unknown shape - return empty Place
      return Place(name: '', latitude: 0.0, longitude: 0.0);
    }

    // Backend may return a `formattedAddress` or `address` field instead of `name`.
    final name = map['name'] ?? map['formattedAddress'] ?? map['address'] ?? '';

    // Robust parsing for latitude/longitude coming as num or String
    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    final latitude = parseDouble(map['lat'] ?? map['latitude']);
    final longitude = parseDouble(map['lng'] ?? map['longitude']);

    return Place(
      name: name,
      latitude: latitude,
      longitude: longitude,
      street: map['street'],
      city: map['city'],
      region: map['region'],
      country: map['country'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'speed': speed,
    'payment_method': paymentMethod,
    'go_to': goTo.toPayload(),
    'return_to': returnTo?.toPayload(),
    'image_url': imageUrl,
    'status': status.toApiString(),
    'is_open': isOpen,
    'created_at': createdAt.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
    'runner_id': runnerId,
    'runner_name': runnerName,
    'price': price,
  };

  Errand copyWith({
    String? id,
    String? type,
    List<ErrandTaskDraft>? tasks,
    String? speed,
    String? paymentMethod,
    Place? goTo,
    Place? returnTo,
    String? imageUrl,
    ErrandStatus? status,
    bool? isOpen,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? runnerId,
    String? runnerName,
    double? price,
  }) {
    return Errand(
      id: id ?? this.id,
      type: type ?? this.type,
      tasks: tasks ?? this.tasks,
      speed: speed ?? this.speed,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      goTo: goTo ?? this.goTo,
      returnTo: returnTo ?? this.returnTo,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      isOpen: isOpen ?? this.isOpen,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      runnerId: runnerId ?? this.runnerId,
      runnerName: runnerName ?? this.runnerName,
      price: price ?? this.price,
    );
  }
}
