import 'package:graphql_flutter/graphql_flutter.dart';

class GraphQLClientInstance {
  static late GraphQLClient client;

  static Future<void> init({String? token}) async {
    final httpLink = HttpLink(
      'http://10.0.2.2:8000/graphql/',
    );

    Link link = httpLink;

    if (token != null && token.isNotEmpty) {
      final authLink = AuthLink(
        getToken: () async => 'JWT $token',
      );
      link = authLink.concat(httpLink);
    }

    client = GraphQLClient(
      cache: GraphQLCache(store: InMemoryStore()),
      link: link,
    );
  }

  static Future<void> setToken(String token) async {
    await init(token: token);
  }
}
