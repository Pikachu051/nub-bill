/// API Configuration for Nub-Bill Backend
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nubbill/config/supabase_config.dart';

/// API configuration constants
class ApiConfig {
  /// Base URL for the backend API.
  ///
  /// You can override at build/run time:
  /// `--dart-define=API_BASE_URL=http://<host>:3000`
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (kIsWeb) return 'http://10.0.24.2:3001';
    // if (Platform.isAndroid) return 'http://10.0.2.2:3000'; // Android emulator
    if (Platform.isAndroid) return 'http://10.0.24.2:3001'; // Wireless Debugging
    return 'http://10.0.24.2:3001'; // iOS simulator / desktop
  }

  /// API prefix
  static const String apiPrefix = '/api';

  /// Full API base URL
  static String get apiBaseUrl => '$baseUrl$apiPrefix';
}

/// HTTP client wrapper that injects Supabase JWT token
class ApiClient {
  final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 15);

  /// Get current JWT token from Supabase session
  String? get _accessToken =>
      SupabaseConfig.client.auth.currentSession?.accessToken;

  /// Build headers with authorization
  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};

    final token = _accessToken;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// GET request
  Future<ApiResponse> get(String endpoint) async {
    try {
      final response = await _client.get(
        Uri.parse('${ApiConfig.apiBaseUrl}$endpoint'),
        headers: _headers,
      ).timeout(_timeout);
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// POST request
  Future<ApiResponse> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${ApiConfig.apiBaseUrl}$endpoint'),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(_timeout);
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// PATCH request
  Future<ApiResponse> patch(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _client.patch(
        Uri.parse('${ApiConfig.apiBaseUrl}$endpoint'),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(_timeout);
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// DELETE request
  Future<ApiResponse> delete(String endpoint) async {
    try {
      final response = await _client.delete(
        Uri.parse('${ApiConfig.apiBaseUrl}$endpoint'),
        headers: _headers,
      ).timeout(_timeout);
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// PUT request
  Future<ApiResponse> put(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final response = await _client.put(
        Uri.parse('${ApiConfig.apiBaseUrl}$endpoint'),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(_timeout);
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// POST multipart request (for file uploads)
  Future<ApiResponse> uploadFile(
    String endpoint,
    List<int> fileBytes,
    String fileName,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.apiBaseUrl}$endpoint'),
      );

      request.headers.addAll(_headers);
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }
}

/// API Response wrapper
class ApiResponse {
  final int? statusCode;
  final dynamic data;
  final String? error;

  ApiResponse({this.statusCode, this.data, this.error});

  bool get isSuccess =>
      statusCode != null && statusCode! >= 200 && statusCode! < 300;

  factory ApiResponse.fromHttpResponse(http.Response response) {
    dynamic data;
    String? error;

    try {
      if (response.body.isNotEmpty) {
        data = jsonDecode(response.body);
        // Check if response contains an error field
        if (data is Map && data.containsKey('error')) {
          error = data['error']?.toString();
        }
      }
    } catch (e) {
      data = response.body;
    }

    return ApiResponse(
      statusCode: response.statusCode,
      data: data,
      error: error,
    );
  }

  factory ApiResponse.error(String message) {
    return ApiResponse(error: message);
  }
}
