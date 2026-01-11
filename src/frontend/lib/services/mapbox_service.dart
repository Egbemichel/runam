import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/place_models.dart';


class MapboxService {
  Future<List<Place>> searchPlaces(String query) async {
    if (query.isEmpty) return [];

    final token = dotenv.env['MAPBOX_PUBLIC_TOKEN'];
    final url =
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json'
        '?autocomplete=true&limit=5&access_token=$token';

    final res = await http.get(Uri.parse(url));
    final data = jsonDecode(res.body);

    return (data['features'] as List).map((f) {
      return Place(
        name: f['place_name'],
        lng: f['center'][0],
        lat: f['center'][1],
      );
    }).toList();
  }
}
