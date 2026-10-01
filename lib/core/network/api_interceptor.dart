import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/core/utils/logger.dart';

class ApiInterceptor extends Interceptor {
  ApiInterceptor(this._ref);

  final Ref _ref;

  /// Completer-based mutex to prevent concurrent token refresh requests.
  ///
  /// Resolves to `true` when a refresh succeeds (so waiting requests retry
  /// with the new token) or `false` when it fails (so they reject). It never
  /// carries a [Response] — each waiting request retries its own
  /// [RequestOptions] so concurrent 401s never share a response object.
  Completer<bool>? _refreshCompleter;

  static final _timeoutOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 10),
  );

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _ref.read(localStorageProvider).authToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await _handleUnauthorized(err, handler);
      return;
    }

    final message = switch (err.type) {
      DioExceptionType.connectionTimeout => 'Connection timed out',
      DioExceptionType.sendTimeout => 'Request timed out',
      DioExceptionType.receiveTimeout => 'Server response timed out',
      DioExceptionType.badResponse =>
        'Server error (${err.response?.statusCode})',
      DioExceptionType.cancel => 'Request was cancelled',
      DioExceptionType.connectionError =>
        'Connection failed: ${err.message ?? "Unable to reach server"}',
      _ =>
        'Network error (${err.type.name}): ${err.message ?? "Unknown error"}',
    };
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: message,
      ),
    );
  }

  Future<void> _handleUnauthorized(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // A refresh is already in-flight — wait for it, then retry this request.
    if (_refreshCompleter != null) {
      try {
        final refreshed = await _refreshCompleter!.future;
        if (!refreshed) {
          _clearAuthAndReject(err, handler);
          return;
        }
        final newToken = _ref.read(localStorageProvider).authToken;
        if (newToken == null) {
          _clearAuthAndReject(err, handler);
          return;
        }
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';
        handler.resolve(await _retry(opts));
      } on Exception catch (e) {
        appLogger.e('Token refresh retry failed (waiting request)', error: e);
        _clearAuthAndReject(err, handler);
      }
      return;
    }

    // First 401 — lead a refresh. Always reset the completer in `finally` so
    // no error path can leave it dangling (which would hang every subsequent
    // authenticated request on a future that never completes).
    final completer = Completer<bool>();
    _refreshCompleter = completer;
    try {
      final refreshed = await _doRefresh(err.requestOptions.baseUrl);
      if (!refreshed) {
        completer.complete(false);
        _clearAuthAndReject(err, handler);
        return;
      }
      final newToken = _ref.read(localStorageProvider).authToken;
      if (newToken == null) {
        completer.complete(false);
        _clearAuthAndReject(err, handler);
        return;
      }
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newToken';
      final retryResponse = await _retry(opts);
      completer.complete(true);
      handler.resolve(retryResponse);
    } on Exception catch (e) {
      appLogger.e('Token refresh failed (initiating request)', error: e);
      if (!completer.isCompleted) completer.complete(false);
      _clearAuthAndReject(err, handler);
    } finally {
      _refreshCompleter = null;
    }
  }

  /// Calls `/api/auth/refresh`, persists the new tokens, and returns whether
  /// the refresh succeeded.
  ///
  /// Uses a fresh [Dio] (no interceptors) to avoid recursion on its own 401.
  /// Every field access uses a type check rather than a cast, so a malformed
  /// response can never throw a [TypeError] — only network [Exception]s can
  /// escape, and they are caught and logged here.
  Future<bool> _doRefresh(String baseUrl) async {
    final localStorage = _ref.read(localStorageProvider);
    final token = localStorage.refreshToken;
    if (token == null) return false;

    final refreshDio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: const {'Content-Type': 'application/json'},
        connectTimeout: _timeoutOptions.connectTimeout,
        receiveTimeout: _timeoutOptions.receiveTimeout,
        sendTimeout: _timeoutOptions.sendTimeout,
      ),
    );

    try {
      final refreshResponse = await refreshDio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': token},
      );
      final data = refreshResponse.data;
      final success = data?['success'] == true;
      final authData = data?['data'];
      if (!success || authData is! Map<String, dynamic>) return false;

      final newAccessToken = authData['accessToken'];
      if (newAccessToken is! String) return false;

      await localStorage.setAuthToken(newAccessToken);
      final newRefreshToken = authData['refreshToken'];
      if (newRefreshToken is String) {
        await localStorage.setRefreshToken(newRefreshToken);
      }
      return true;
    } on Exception catch (e) {
      appLogger.e('Token refresh request failed', error: e);
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions opts) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: opts.baseUrl,
        headers: opts.headers,
        connectTimeout: _timeoutOptions.connectTimeout,
        receiveTimeout: _timeoutOptions.receiveTimeout,
        sendTimeout: _timeoutOptions.sendTimeout,
      ),
    );
    // Add logging in debug mode for retry requests.
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
    return dio.request(
      opts.path,
      data: opts.data,
      queryParameters: opts.queryParameters,
      options: Options(method: opts.method, headers: opts.headers),
    );
  }

  void _clearAuthAndReject(DioException err, ErrorInterceptorHandler handler) {
    _ref.read(localStorageProvider).clearAuthData();
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: 'Session expired. Please sign in again.',
      ),
    );
  }
}
