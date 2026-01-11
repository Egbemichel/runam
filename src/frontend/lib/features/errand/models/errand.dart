import '../../../models/place_models.dart';

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

  static ErrandStatus fromString(String status) {
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
  final String instructions;
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
    required this.instructions,
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
    return Errand(
      id: json['id'] as String,
      type: json['type'] as String,
      instructions: json['instructions'] as String,
      speed: json['speed'] as String,
      paymentMethod: json['paymentMethod'] ?? json['payment_method'] as String,
      goTo: _parsePlaceFromJson(json['goTo'] ?? json['go_to']),
      returnTo: json['returnTo'] != null || json['return_to'] != null
          ? _parsePlaceFromJson(json['returnTo'] ?? json['return_to'])
          : null,
      imageUrl: json['imageUrl'] ?? json['image_url'],
      status: ErrandStatusExtension.fromString(json['status'] as String),
      isOpen: json['isOpen'] ?? json['is_open'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
      expiresAt: DateTime.parse(json['expiresAt'] ?? json['expires_at']),
      runnerId: json['runnerId'] ?? json['runner_id'],
      runnerName: json['runnerName'] ?? json['runner_name'],
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
    );
  }

  static Place _parsePlaceFromJson(Map<String, dynamic> json) {
    return Place(
      name: json['name'] ?? '',
      lat: (json['lat'] ?? json['latitude'] ?? 0).toDouble(),
      lng: (json['lng'] ?? json['longitude'] ?? 0).toDouble(),
      street: json['street'],
      city: json['city'],
      region: json['region'],
      country: json['country'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'instructions': instructions,
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
    String? instructions,
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
      instructions: instructions ?? this.instructions,
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

