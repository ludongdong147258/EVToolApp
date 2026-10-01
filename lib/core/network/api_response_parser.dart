import 'package:dio/dio.dart';

export 'api_result.dart';
import 'package:ev_tool_app/core/network/api_result.dart';
import 'package:ev_tool_app/core/utils/logger.dart';

/// Parses a raw Dio response map into [ApiResult<T>].
///
/// Expects the backend envelope: `{ "success": bool, "data": T?, "error": String? }`
ApiResult<T> parseResponse<T>(
  Map<String, dynamic>? data,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (data == null) {
    return const ApiResult.failure('Empty response from server');
  }
  final success = data['success'] as bool? ?? false;
  if (!success) {
    final error = data['error'] as String? ?? 'Unknown error';
    return ApiResult.failure(error);
  }
  final payload = data['data'];
  if (payload is! Map<String, dynamic>) {
    return const ApiResult.failure('No data in response');
  }
  return ApiResult.success(fromJson(payload));
}

/// Executes a Dio call and parses the response into [ApiResult<T>].
///
/// Wraps the entire call in error handling, so callers don't need
/// try/catch blocks. Expects the backend envelope format.
///
/// Server payloads are untrusted, so this trust boundary catches every
/// error — a malformed body or a [fromJson] cast failure must never
/// escape as an unhandled [Error]; it is logged and surfaced as a
/// failure instead.
Future<ApiResult<T>> safeApiCall<T>(
  Future<Response<Map<String, dynamic>>> Function() call,
  T Function(Map<String, dynamic>) fromJson,
) async {
  try {
    final response = await call();
    return parseResponse(response.data, fromJson);
  } on DioException catch (e) {
    return ApiResult.failure(
      e.error?.toString() ?? 'Network error',
      code: e.response?.statusCode,
    );
  } catch (e) {
    appLogger.e('Failed to process server response', error: e);
    return const ApiResult.failure('Failed to process server response');
  }
}

/// Executes a Dio call for endpoints where `data['data']` is a JSON array.
///
/// Same trust-boundary guarantees as [safeApiCall]; non-map entries in the
/// array are skipped rather than crashing the parse.
Future<ApiResult<List<T>>> safeApiCallList<T>(
  Future<Response<Map<String, dynamic>>> Function() call,
  T Function(Map<String, dynamic>) fromJson,
) async {
  try {
    final response = await call();
    final data = response.data;
    if (data == null) {
      return const ApiResult.failure('Empty response from server');
    }
    final success = data['success'] as bool? ?? false;
    if (!success) {
      final error = data['error'] as String? ?? 'Unknown error';
      return ApiResult.failure(error);
    }
    final payload = data['data'];
    if (payload is! List) {
      return const ApiResult.failure('No data in response');
    }
    final items = payload
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList();
    return ApiResult.success(items);
  } on DioException catch (e) {
    return ApiResult.failure(
      e.error?.toString() ?? 'Network error',
      code: e.response?.statusCode,
    );
  } catch (e) {
    appLogger.e('Failed to process server response', error: e);
    return const ApiResult.failure('Failed to process server response');
  }
}

/// Executes a Dio call for void-returning endpoints (e.g., logout).
///
/// Checks the envelope `success` flag but does not parse a `data` payload.
Future<ApiResult<void>> safeApiCallVoid(
  Future<Response<Map<String, dynamic>>> Function() call,
) async {
  try {
    final response = await call();
    final data = response.data;
    if (data == null) {
      return const ApiResult.failure('Empty response from server');
    }
    final success = data['success'] as bool? ?? false;
    if (!success) {
      final error = data['error'] as String? ?? 'Unknown error';
      return ApiResult.failure(error);
    }
    return const ApiResult.success(null);
  } on DioException catch (e) {
    return ApiResult.failure(
      e.error?.toString() ?? 'Network error',
      code: e.response?.statusCode,
    );
  } catch (e) {
    appLogger.e('Failed to process server response', error: e);
    return const ApiResult.failure('Failed to process server response');
  }
}
