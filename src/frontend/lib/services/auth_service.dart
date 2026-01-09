import 'package:graphql_flutter/graphql_flutter.dart';
import '../models/app_user.dart';
import 'graphql_client.dart';

class AuthService {
  final GraphQLClient _client = GraphQLClientInstance.client;

  Future<Map<String, dynamic>> verifyGoogleToken(String idToken) async {
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

    print('🔵 Executing GraphQL mutation...');
    final result = await _client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {
          'idToken': idToken,
        },
      ),
    );

    if (result.hasException) {
      print('❌ GraphQL Exception: ${result.exception}');
      throw result.exception!;
    }

    print('✅ GraphQL query successful');
    print('   Response data: ${result.data}');

    final responseData = result.data!['verifyGoogleToken'];
    print('   Extracted data: $responseData');

    return responseData;
  }

  /// Returns structured authentication response with access token and user
  Future<AuthResponse> authenticateWithGoogle(String idToken) async {
    print('🔵 Calling verifyGoogleToken...');
    final data = await verifyGoogleToken(idToken);

    print('🔵 Parsing response data...');
    print('   Access token present: ${data['access'] != null}');
    print('   User data present: ${data['user'] != null}');

    final accessToken = data['access'] as String;
    final userData = data['user'] as Map<String, dynamic>;

    print('   User name: ${userData['name']}');
    print('   User email: ${userData['email']}');

    final user = AppUser.fromJson(userData);
    print('✅ User model created successfully');

    return AuthResponse(
      accessToken: accessToken,
      user: user,
    );
  }
}

/// Authentication response containing access token and user data
class AuthResponse {
  final String accessToken;
  final AppUser user;

  AuthResponse({
    required this.accessToken,
    required this.user,
  });
}
