import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/network/api_response_parser.dart';

import '../../helpers/fake_dio_adapter.dart';

Map<String, dynamic> _identity(Map<String, dynamic> json) => json;

void main() {
  group('parseResponse', () {
    test('returns success with parsed payload for a valid envelope', () {
      // Arrange
      final data = {
        'success': true,
        'data': {'id': 'station-1'},
        'error': null,
      };

      // Act
      final result = parseResponse(data, _identity);

      // Assert
      expect(
        result,
        isA<ApiSuccess<Map<String, dynamic>>>().having(
          (s) => s.data['id'],
          'id',
          'station-1',
        ),
      );
    });

    test('returns failure with error message when success is false', () {
      // Arrange
      final data = {'success': false, 'data': null, 'error': 'Bad request'};

      // Act
      final result = parseResponse(data, _identity);

      // Assert
      expect(
        result,
        isA<ApiFailure<Map<String, dynamic>>>().having(
          (f) => f.message,
          'message',
          'Bad request',
        ),
      );
    });

    test('returns failure for a null response', () {
      // Act
      final result = parseResponse<Map<String, dynamic>>(null, _identity);

      // Assert
      expect(result, isA<ApiFailure<Map<String, dynamic>>>());
    });

    test('returns failure when data payload is not a map', () {
      // Arrange
      final data = {'success': true, 'data': 'not-a-map'};

      // Act
      final result = parseResponse(data, _identity);

      // Assert
      expect(result, isA<ApiFailure<Map<String, dynamic>>>());
    });
  });

  group('safeApiCall', () {
    test('parses a successful envelope through a real Dio call', () async {
      // Arrange
      final dio = Dio()
        ..httpClientAdapter = FakeDioAdapter(
          (options) => jsonResponseBody({
            'success': true,
            'data': {'name': 'EV Tool'},
          }),
        );

      // Act
      final result = await safeApiCall(
        () => dio.get<Map<String, dynamic>>('/api/home'),
        _identity,
      );

      // Assert
      expect(
        result,
        isA<ApiSuccess<Map<String, dynamic>>>().having(
          (s) => s.data['name'],
          'name',
          'EV Tool',
        ),
      );
    });

    test('returns failure with status code on a DioException', () async {
      // Arrange
      final dio = Dio()
        ..httpClientAdapter = FakeDioAdapter(
          (options) => jsonResponseBody({
            'success': false,
            'error': 'Unauthorized',
          }, status: 401),
        );

      // Act
      final result = await safeApiCall(
        () => dio.get<Map<String, dynamic>>('/api/protected'),
        _identity,
      );

      // Assert
      expect(result, isA<ApiFailure<Map<String, dynamic>>>());
    });
  });

  group('safeApiCallList', () {
    test('skips malformed non-map entries instead of crashing', () async {
      // Arrange
      final dio = Dio()
        ..httpClientAdapter = FakeDioAdapter(
          (options) => jsonResponseBody({
            'success': true,
            'data': [
              {'id': 'a'},
              'malformed-entry',
              {'id': 'b'},
            ],
          }),
        );

      // Act
      final result = await safeApiCallList(
        () => dio.get<Map<String, dynamic>>('/api/stations'),
        _identity,
      );

      // Assert
      expect(
        result,
        isA<ApiSuccess<List<Map<String, dynamic>>>>().having(
          (s) => s.data.length,
          'length',
          2,
        ),
      );
    });

    test('returns failure when payload is not a list', () async {
      // Arrange
      final dio = Dio()
        ..httpClientAdapter = FakeDioAdapter(
          (options) => jsonResponseBody({
            'success': true,
            'data': {'id': 'not-a-list'},
          }),
        );

      // Act
      final result = await safeApiCallList(
        () => dio.get<Map<String, dynamic>>('/api/stations'),
        _identity,
      );

      // Assert
      expect(result, isA<ApiFailure<List<Map<String, dynamic>>>>());
    });
  });

  group('safeApiCallVoid', () {
    test('returns success for a void endpoint with success envelope', () async {
      // Arrange
      final dio = Dio()
        ..httpClientAdapter = FakeDioAdapter(
          (options) => jsonResponseBody({'success': true}),
        );

      // Act
      final result = await safeApiCallVoid(
        () => dio.post<Map<String, dynamic>>('/api/logout'),
      );

      // Assert
      expect(result, isA<ApiSuccess<void>>());
    });

    test('returns failure when envelope reports an error', () async {
      // Arrange
      final dio = Dio()
        ..httpClientAdapter = FakeDioAdapter(
          (options) =>
              jsonResponseBody({'success': false, 'error': 'Expired token'}),
        );

      // Act
      final result = await safeApiCallVoid(
        () => dio.post<Map<String, dynamic>>('/api/logout'),
      );

      // Assert
      expect(result, isA<ApiFailure<void>>());
    });
  });
}
