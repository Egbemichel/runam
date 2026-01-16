import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/place_models.dart';

class MapboxService {
  static const int _timeoutSeconds = 10;
  static const int _maxRetries = 2;

  Future<List<Place>> searchPlaces(String query) async {
    if (query.isEmpty) return [];

    final token = dotenv.env['MAPBOX_PUBLIC_TOKEN'];
    if (token == null || token.isEmpty) {
      _log('MAPBOX_PUBLIC_TOKEN not found in .env');
      return [];
    }

    // URL encode the query to handle special characters
    final encodedQuery = Uri.encodeComponent(query);
    final url =
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
        '?autocomplete=true&limit=5&access_token=$token';

    // Retry logic for network issues
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: _timeoutSeconds));

        if (res.statusCode != 200) {
          _log('API returned status ${res.statusCode}');
          return [];
        }

        final data = jsonDecode(res.body);

        if (data['features'] == null) {
          _log('No features in response');
          return [];
        }

        return (data['features'] as List).map((f) {
          final context = f['context'] as List? ?? [];

          // Extract address components from context
          String? city;
          String? region;
          String? country;

          for (final ctx in context) {
            final id = ctx['id'] as String? ?? '';
            final text = ctx['text'] as String?;

            if (id.startsWith('place')) {
              city = text;
            } else if (id.startsWith('region')) {
              region = text;
            } else if (id.startsWith('country')) {
              country = text;
            }
          }

          return Place(
            name: f['text'] ?? f['place_name'] ?? 'Unknown',
            longitude: (f['center'][0] as num).toDouble(),
            latitude: (f['center'][1] as num).toDouble(),
            street: f['properties']?['address'],
            city: city,
            region: region,
            country: country,
          );
        }).toList();
      } on TimeoutException {
        _log('Request timed out (attempt ${attempt + 1}/${_maxRetries + 1})');
        if (attempt == _maxRetries) {
          return [];
        }
        // Wait before retry
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } catch (e) {
        _log('Error searching places: $e');
        if (attempt == _maxRetries) {
          return [];
        }
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }

    return [];
  }

  void _log(String message) {
    // ignore: avoid_print
    print('MapboxService: $message');
  }
}
