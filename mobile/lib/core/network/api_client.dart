import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
        );

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
