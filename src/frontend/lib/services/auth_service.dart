import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'http://10.0.2.2:8000/api/auth';

  Future<Map<String, dynamic>> verifyGoogleToken(String idToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/google/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    if (response.statusCode != 200) {
      throw Exception('Auth failed');
    }

    return jsonDecode(response.body);
  }
}
