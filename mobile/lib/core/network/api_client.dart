import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Why the server stopped accepting the saved session.
enum AuthFailure { sessionExpired, blocked }

class ApiClient {
  static String get defaultBaseUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.startsWith('file://')) {
        return '$origin/api';
      }
    }
    return 'http://127.0.0.1:3000/api';
  }

  final Dio dio;
  final _authFailures = StreamController<AuthFailure>.broadcast();

  ApiClient({String? baseUrl, String? token})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? defaultBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          final failure = authFailureOf(error);
          if (failure != null) _authFailures.add(failure);
          handler.next(error);
        },
      ),
    );
  }

  /// Emits when an authenticated request is rejected because the token
  /// expired or the account was blocked; the shell then signs out.
  Stream<AuthFailure> get authFailures => _authFailures.stream;

  bool get hasToken => dio.options.headers.containsKey('Authorization');

  void updateToken(String? token) {
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      dio.options.headers.remove('Authorization');
    }
  }

  void updateBaseUrl(String baseUrl) {
    dio.options.baseUrl = baseUrl;
  }
}

/// Server error code from `{ "error": { "code": ... } }`, if any.
String? apiErrorCode(DioException error) {
  final data = error.response?.data;
  if (data is Map && data['error'] is Map) {
    return data['error']['code'] as String?;
  }
  return null;
}

/// Session problems of a request that carried a token. A 401 from
/// `/auth/login` is a wrong password, not an expired session.
AuthFailure? authFailureOf(DioException error) {
  final options = error.requestOptions;
  if (!options.headers.containsKey('Authorization')) return null;
  if (options.path.startsWith('/auth/login') ||
      options.path.startsWith('/auth/register') ||
      options.path.startsWith('/auth/smartnation')) {
    return null;
  }
  if (apiErrorCode(error) == 'USER_BLOCKED') return AuthFailure.blocked;
  if (error.response?.statusCode == 401) return AuthFailure.sessionExpired;
  return null;
}
