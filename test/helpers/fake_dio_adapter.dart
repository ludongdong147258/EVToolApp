import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A minimal [HttpClientAdapter] that returns a canned JSON response body,
/// letting repository tests exercise the real Dio -> safeApiCall -> parseResponse
/// path without Mockito codegen.
class FakeDioAdapter implements HttpClientAdapter {
  FakeDioAdapter(this._responder);

  final ResponseBody Function(RequestOptions options) _responder;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => _responder(options);

  @override
  void close({bool force = false}) {}
}

/// Builds a JSON [ResponseBody] matching the backend envelope shape.
ResponseBody jsonResponseBody(
  Map<String, dynamic> envelope, {
  int status = 200,
}) {
  return _jsonResponseBody(envelope, status);
}

/// Builds a JSON [ResponseBody] whose top level is an array
/// (e.g. Open Charge Map /v3/poi/).
ResponseBody jsonListResponseBody(List<dynamic> body, {int status = 200}) {
  return _jsonResponseBody(body, status);
}

ResponseBody _jsonResponseBody(Object body, int status) {
  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(body)));
  return ResponseBody(
    Stream<Uint8List>.value(bytes),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

/// Builds a non-JSON [ResponseBody] (e.g. Cloudflare HTML with 200).
ResponseBody textResponseBody(String text, {int status = 200}) {
  final bytes = Uint8List.fromList(utf8.encode(text));
  return ResponseBody(
    Stream<Uint8List>.value(bytes),
    status,
    headers: {
      Headers.contentTypeHeader: ['text/html'],
    },
  );
}
