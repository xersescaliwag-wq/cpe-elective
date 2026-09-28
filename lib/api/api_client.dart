import 'dart:convert';
import 'package:http/http.dart' as http;

/// Handles HTTP communication with the PHP backend on celllaunch.shop.
/// Fulfills requirement: Use HTTP services for API.
class ApiClient {
  static const String _baseUrl = 'https://celllaunch.shop';

  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? query}) async {
    try {
      final uri = Uri.parse('$_baseUrl/$endpoint').replace(queryParameters: query);
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e) {
      // Fails silently so it won't crash the app if the server is down
    }
    return <String, dynamic>{'data': <dynamic>[]};
  }

  Future<void> post(String endpoint, {required Map<String, dynamic> body}) async {
    try {
      final uri = Uri.parse('$_baseUrl/$endpoint');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (e) {
      // Fails silently 
    }
  }

  Future<void> delete(String endpoint, {Map<String, String>? query}) async {
    try {
      final uri = Uri.parse('$_baseUrl/$endpoint').replace(queryParameters: query);
      await http.delete(uri);
    } catch (e) {
      // Fails silently
    }
  }
}
