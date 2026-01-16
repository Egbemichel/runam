import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'token_refresher.dart';

class GraphQLClientInstance {
  static late GraphQLClient client;
  static String? _currentUrl;
  static String? _accessToken;

  static bool _isRefreshing = false;

  static Future<void> init({String? token}) async {
    final baseUrl = dotenv.env['GRAPHQL_URL'] ?? 'http://10.0.2.2:8000/graphql/';
    _currentUrl = baseUrl;
    _accessToken = token;

    final httpClient = http.Client();
    final httpLink = HttpLink(
      baseUrl,
      httpClient: httpClient,
      defaultHeaders: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    // Auth link only if token exists
    Link link = httpLink;
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      final authLink = AuthLink(
        getToken: () async => 'JWT $_accessToken',
      );
      link = authLink.concat(httpLink);
    }

    // Error link: refresh token once per request
    final errorLink = ErrorLink(
      onGraphQLError: (request, forward, response) async* {
        final hasExpired = response?.errors?.any(
              (e) => e.message.contains('Signature has expired'),
        ) ?? false;

        final attempted = request.context.entry<HttpLinkHeaders>()?.headers['x-refresh-attempted'] == 'true';

        if (!hasExpired || attempted) {
          yield response!;
          return;
        }

        if (_isRefreshing) {
          // Wait for other refresh to finish
          await Future.delayed(Duration(milliseconds: 100));
          yield* forward(request);
          return;
        }

        print('🔁 [GraphQL] Access token expired, refreshing...');
        _isRefreshing = true;

        final newToken = await TokenRefresher.refresh();
        _isRefreshing = false;

        if (newToken == null) {
          print('❌ [GraphQL] Failed to refresh token');
          yield response;
          return;
        }

        print('✅ [GraphQL] Token refreshed, retrying request...');

        final updatedRequest = request.withContextEntry(
          HttpLinkHeaders(
            headers: {
              'Authorization': 'JWT $newToken',
              'x-refresh-attempted': 'true',
            },
          ),
        );

        yield* forward(updatedRequest);
      },
    );

    link = Link.from([errorLink, link]);

    client = GraphQLClient(
      cache: GraphQLCache(store: InMemoryStore()),
      link: link,
      defaultPolicies: DefaultPolicies(
        query: Policies(fetch: FetchPolicy.networkOnly),
        mutate: Policies(fetch: FetchPolicy.networkOnly),
      ),
    );

    print('✅ [GraphQL] Client initialized successfully');
  }

  static Future<void> setToken(String token) async {
    _accessToken = token;
    await init(token: token);
  }

  static GraphQLClient get rawClient => client;
  static String? get currentUrl => _currentUrl;
}
