import 'dart:convert';

/// Validated API response wrapper.
/// Ensures responses from the server match expected format before parsing.
class ApiResponse {
  final bool success;
  final Map<String, dynamic>? data;
  final String? message;
  final String? apiVersion;
  final int statusCode;

  ApiResponse._({
    required this.success,
    this.data,
    this.message,
    this.apiVersion,
    required this.statusCode,
  });

  /// Parse an HTTP response body into a validated ApiResponse.
  /// If the response doesn't match expected format, wraps it safely.
  factory ApiResponse.fromHttpResponse(dynamic httpResponse) {
    final int statusCode;
    final String body;

    // Support both http.Response and custom response objects
    if (httpResponse is Map) {
      statusCode = (httpResponse['statusCode'] as int?) ?? 0;
      body = (httpResponse['body'] as String?) ?? '{}';
    } else {
      statusCode = httpResponse.statusCode as int;
      body = httpResponse.body as String;
    }

    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return ApiResponse._(
          success: (decoded['success'] as bool?) ?? (statusCode >= 200 && statusCode < 400),
          data: decoded,
          message: decoded['message'] as String?,
          apiVersion: decoded['apiVersion'] as String?,
          statusCode: statusCode,
        );
      }

      // Response is not a Map — wrap it
      return ApiResponse._(
        success: statusCode >= 200 && statusCode < 400,
        data: {'rawData': decoded},
        message: null,
        apiVersion: null,
        statusCode: statusCode,
      );
    } catch (e) {
      // JSON parsing failed — server sent invalid response
      return ApiResponse._(
        success: false,
        data: null,
        message: 'Invalid server response',
        apiVersion: null,
        statusCode: statusCode,
      );
    }
  }

  /// Check if a required field exists and is of expected type
  bool hasField(String key) => data != null && data!.containsKey(key);

  /// Get a typed field with fallback
  T getField<T>(String key, T fallback) {
    if (data == null || !data!.containsKey(key)) return fallback;
    final value = data![key];
    if (value is T) return value;
    return fallback;
  }

  /// Check if response indicates the API version is supported
  bool get isVersionSupported => apiVersion == null || apiVersion == 'v1';

  @override
  String toString() => 'ApiResponse(success: $success, status: $statusCode, version: $apiVersion)';
}
