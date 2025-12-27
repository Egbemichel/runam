import 'package:graphql_flutter/graphql_flutter.dart';
import 'graphql_client.dart';

class AuthService {
  final GraphQLClient _client = GraphQLClientInstance.client;

  Future<Map<String, dynamic>> verifyGoogleToken(String idToken) async {
    const String mutation = r'''
      mutation VerifyGoogleToken($idToken: String!) {
        verifyGoogleToken(idToken: $idToken) {
          access
          user {
            avatar
          }
        }
      }
    ''';

    final result = await _client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {
          'idToken': idToken, // ✅ correct variable name
        },
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    return result.data!['verifyGoogleToken'];
  }
}
