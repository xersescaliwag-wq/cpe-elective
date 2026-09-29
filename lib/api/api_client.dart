import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';


class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client})
      : _client = client ?? http.Client(),
        _base = Uri.parse(ApiConfig.baseUrl);

  final http.Client _client;
  final Uri _base;

  static const Duration _timeout = Duration(seconds: 12);

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = _base.resolve(path);
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  Map<String, String> get _headers => <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-API-Key': ApiConfig.apiKey,
      };

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) {
    return _send(() => _client.get(_uri(path, query), headers: _headers));
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _send(() => _client.post(
          _uri(path),
          headers: _headers,
          body: jsonEncode(body ?? const <String, dynamic>{}),
        ));
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? query,
  }) {
    return _send(
      () => _client.delete(_uri(path, query), headers: _headers),
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } on SocketException {
      throw ApiException('No internet connection. Please try again.');
    } on http.ClientException {
      throw ApiException('Network error. Please try again.');
    }

    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'The server returned an unexpected response.',
        statusCode: response.statusCode,
      );
    }

    final okStatus = response.statusCode >= 200 && response.statusCode < 300;
    if (!okStatus) {
      final error = json['error'];
      throw ApiException(
        error is String ? error : 'Request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    if (json['success'] == false) {
      final error = json['error'];
      throw ApiException(
        error is String ? error : 'Operation failed.',
        statusCode: response.statusCode,
      );
    }
    return json;
  }
}