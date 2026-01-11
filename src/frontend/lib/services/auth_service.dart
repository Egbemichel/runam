import 'package:graphql_flutter/graphql_flutter.dart';
import '../models/app_user.dart';
import 'graphql_client.dart';

/// AuthService handles communication with Django backend for authentication
/// Uses GraphQL mutations to verify Google tokens and manage user sessions
class AuthService {

  /// Sends Google ID Token to Django backend for verification
  /// Backend will:
  /// 1. Verify the token with Google
  /// 2. Extract user info from token payload
  /// 3. Create or retrieve user account
  /// 4. Issue Django JWT token
  Future<AuthResponse> verifyGoogleToken(String idToken) async {
    print('🌐 [AuthService] verifyGoogleToken called');
    print('🔑 [AuthService] ID Token length: ${idToken.length}');
    print('🌐 [AuthService] GraphQL URL: ${GraphQLClientInstance.currentUrl}');

    const String mutation = r'''
      mutation VerifyGoogleToken($idToken: String!) {
        verifyGoogleToken(idToken: $idToken) {
          access
          user {
            id
            name
            email
            avatar
            trustScore
            roles {
              name
            }
            location {
              id
              latitude
              longitude
              label
              type
              isActive
            }
          }
        }
      }
    ''';

    final client = GraphQLClientInstance.client;
    print('📡 [AuthService] GraphQL client ready, sending mutation...');
    print('📡 [AuthService] Mutation variables: {idToken: [${idToken.substring(0, 20)}...]}');

    try {
      print('⏳ [AuthService] Awaiting mutation response...');
      final stopwatch = Stopwatch()..start();

      final result = await client.mutate(
        MutationOptions(
          document: gql(mutation),
          variables: {'idToken': idToken},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      stopwatch.stop();
      print('📥 [AuthService] Mutation response received in ${stopwatch.elapsedMilliseconds}ms');
      print('📥 [AuthService] Result data: ${result.data}');
      print('📥 [AuthService] Result exception: ${result.exception}');

      if (result.hasException) {
        final exception = result.exception!;
        print('❌ [AuthService] GraphQL Exception: $exception');

        // Extract meaningful error message
        if (exception.graphqlErrors.isNotEmpty) {
          final errorMsg = exception.graphqlErrors.first.message;
          print('❌ [AuthService] GraphQL Error: $errorMsg');
          throw AuthException(errorMsg);
        }

        if (exception.linkException != null) {
          print('❌ [AuthService] Link Exception: ${exception.linkException}');
          throw AuthException('Network error. Please check your connection.');
        }

        throw AuthException('Authentication failed. Please try again.');
      }

      print('📦 [AuthService] Response data: ${result.data}');
      final data = result.data?['verifyGoogleToken'];
      if (data == null) {
        print('❌ [AuthService] verifyGoogleToken data is null');
        throw AuthException('Invalid response from server');
      }

      print('✅ [AuthService] Token verification successful');
      print('👤 [AuthService] User data received: ${data['user']}');

      return AuthResponse(
        accessToken: data['access'] as String,
        user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
      );
    } catch (e, stackTrace) {
      print('❌ [AuthService] Exception in verifyGoogleToken: $e');
      print('📚 [AuthService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Fetches the current user data using the stored JWT
  Future<AppUser> fetchCurrentUser() async {
    const String query = r'''
      query Me {
        me {
          id
          name
          email
          avatar
          trustScore
          roles {
            name
          }
          location {
            id
            latitude
            longitude
            label
            type
            isActive
          }
        }
      }
    ''';

    final client = GraphQLClientInstance.client;

    final result = await client.query(
      QueryOptions(
        document: gql(query),
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final exception = result.exception!;

      if (exception.graphqlErrors.isNotEmpty) {
        throw AuthException(exception.graphqlErrors.first.message);
      }

      throw AuthException('Failed to fetch user data.');
    }

    final data = result.data?['me'];
    if (data == null) {
      throw AuthException('Invalid user data received');
    }

    return AppUser.fromJson(data as Map<String, dynamic>);
  }

  /// Updates user location on the server
  Future<void> updateLocation({
    required String mode,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    const mutation = r'''
      mutation UpdateUserLocation(
        $mode: String!,
        $latitude: Float!,
        $longitude: Float!,
        $address: String
      ) {
        updateUserLocation(
          mode: $mode,
          latitude: $latitude,
          longitude: $longitude,
          address: $address
        ) {
          location {
            id
            mode
            latitude
            longitude
            address
          }
        }
      }
    ''';

    final client = GraphQLClientInstance.client;

    await client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {
          'mode': mode,
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        },
      ),
    );
  }

  /// Logs out the user (optional server-side cleanup)
  Future<void> logout() async {
    // Add server-side logout mutation if needed
    // This could invalidate the JWT on the server side
  }
}

/// Custom exception for authentication errors
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// Authentication response from Django backend
/// Contains the Django-issued JWT and user data
class AuthResponse {
  final String accessToken;
  final AppUser user;

  AuthResponse({
    required this.accessToken,
    required this.user,
  });
}

