import 'package:get_storage/get_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'graphql_client.dart';

class TokenRefresher {
  static final _storage = GetStorage();

  static Future<String?> refresh() async {
    final refreshToken = _storage.read<String>('refreshToken');
    print('🔑 [TokenRefresher] Stored refresh token: $refreshToken');
    if (refreshToken == null || refreshToken.isEmpty) return null;

    const mutation = r'''
      mutation RefreshToken($refreshToken: String!) {
        refreshToken(refreshToken: $refreshToken) {
          token
        }
      }
    ''';

    // Use a raw client without AuthLink (expired token) for refresh
    final rawClient = GraphQLClient(
      link: HttpLink(GraphQLClientInstance.currentUrl!),
      cache: GraphQLCache(store: InMemoryStore()),
    );

    final result = await rawClient.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {'refreshToken': refreshToken},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      print('❌ [TokenRefresher] Refresh failed: ${result.exception}');
      return null;
    }

    final newToken = result.data?['refreshToken']?['token'];
    if (newToken == null) {
      print('❌ [TokenRefresher] No token returned');
      return null;
    }

    print('🆕 [TokenRefresher] New token: $newToken');
    _storage.write('accessToken', newToken);
    await GraphQLClientInstance.setToken(newToken);

    return newToken;
  }
}
