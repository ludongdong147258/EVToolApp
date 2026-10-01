import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/constants/app_constants.dart';
import 'package:ev_tool_app/core/network/api_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.networkTimeout,
      receiveTimeout: AppConstants.networkTimeout,
      sendTimeout: AppConstants.networkTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Configure custom HttpClient for TLS debugging
  // This allows self-signed certs in debug mode and provides
  // better error messages for connection issues
  if (kDebugMode) {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        // Allow bad certificates in debug mode for easier troubleshooting
        client.badCertificateCallback = (cert, host, port) {
          debugPrint(
            '⚠️ Bad certificate for $host:$port — '
            'issuer: ${cert.issuer}, subject: ${cert.subject}',
          );
          return true;
        };
        return client;
      },
    );
  }

  dio.interceptors.addAll([
    ApiInterceptor(ref),
    if (kDebugMode) LogInterceptor(requestBody: true, responseBody: true),
  ]);
  return dio;
});
