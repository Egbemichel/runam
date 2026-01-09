import 'user_location.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String avatar;
  final int trustScore;
  final List<String> roles;
  final List<UserLocation> locations;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.avatar,
    required this.trustScore,
    required this.roles,
    required this.locations,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    print('🔵 Parsing AppUser from JSON...');
    print('   JSON keys: ${json.keys.toList()}');

    // Handle both 'location' (singular from backend) and 'locations' (plural for storage)
    List<UserLocation> locationsList = [];

    try {
      if (json['location'] != null) {
        print('   Found location (singular)');
        // Backend returns single location object
        locationsList = [UserLocation.fromJson(json['location'] as Map<String, dynamic>)];
        print('   ✅ Location parsed successfully');
      } else if (json['locations'] != null) {
        print('   Found locations (plural)');
        // Handle legacy format with locations array
        locationsList = (json['locations'] as List<dynamic>)
            .map((location) => UserLocation.fromJson(location as Map<String, dynamic>))
            .toList();
        print('   ✅ Locations parsed successfully');
      } else {
        print('   ⚠️ No location data found');
      }
    } catch (e) {
      print('   ❌ Error parsing location: $e');
    }

    try {
      final user = AppUser(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        avatar: json['avatar'] ?? '',
        trustScore: json['trustScore'] ?? 0,
        roles: (json['roles'] as List<dynamic>?)
                ?.map((role) => role['name'] as String)
                .toList() ??
            [],
        locations: locationsList,
      );

      print('✅ AppUser created: ${user.name} (${user.email})');
      return user;
    } catch (e) {
      print('❌ Error creating AppUser: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
      'trustScore': trustScore,
      'roles': roles.map((role) => {'name': role}).toList(),
      'locations': locations.map((location) => location.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'AppUser(id: $id, name: $name, email: $email, trustScore: $trustScore, roles: $roles)';
  }
}

