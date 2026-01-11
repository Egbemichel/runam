import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GraphQLClientInstance {
  static late GraphQLClient client;
  static String? _currentUrl;

  static Future<void> init({String? token}) async {
    final baseUrl = dotenv.env['GRAPHQL_URL'] ?? 'http://10.0.2.2:8000/graphql/';
    _currentUrl = baseUrl;

    print('🔧 [GraphQL] Initializing client...');
    print('🌐 [GraphQL] URL: $baseUrl');
    print('🔑 [GraphQL] Token: ${token != null ? "Present" : "None"}');

    // Create HTTP client with timeout
    final httpClient = http.Client();

    final httpLink = HttpLink(
      baseUrl,
      httpClient: httpClient,
      defaultHeaders: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
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
      defaultPolicies: DefaultPolicies(
        query: Policies(
          fetch: FetchPolicy.networkOnly,
        ),
        mutate: Policies(
          fetch: FetchPolicy.networkOnly,
        ),
      ),
    );

    print('✅ [GraphQL] Client initialized successfully');
  }

  static Future<void> setToken(String token) async {
    print('🔄 [GraphQL] Setting new token...');
    await init(token: token);
  }

  static String? get currentUrl => _currentUrl;
}
