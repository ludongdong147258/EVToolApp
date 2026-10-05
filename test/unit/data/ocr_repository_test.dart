import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/features/ocr/data/ocr_repository.dart';
import 'package:ev_tool_app/features/ocr/data/receipt_image_pipeline.dart';

import '../../helpers/fake_dio_adapter.dart';

class FakePipeline implements ReceiptImagePipeline {
  FakePipeline(this.dataUrl);

  final String dataUrl;
  int callCount = 0;

  @override
  Future<String> toBase64DataUrl(String imagePath) async {
    callCount++;
    return dataUrl;
  }
}

ResponseBody _okResponse(String content) => jsonResponseBody({
  'choices': [
    {
      'message': {'content': content},
    },
  ],
});

ResponseBody _errorResponse(String code, String message, {int status = 200}) =>
    jsonResponseBody({
      'error': {'code': code, 'message': message},
    }, status: status);

const String _dataUrl = 'data:image/jpeg;base64,aGVsbG8=';

OcrRepository _buildRepo(
  List<ResponseBody> responses,
  List<RequestOptions> calls, {
  String apiKey = 'TEST_KEY',
  FakePipeline? pipeline,
}) {
  final dio = Dio(BaseOptions(baseUrl: ocrApiBase));
  dio.httpClientAdapter = FakeDioAdapter((options) {
    calls.add(options);
    if (responses.isEmpty) {
      throw StateError('未预期的额外请求');
    }
    return responses.removeAt(0);
  });
  return OcrRepository(
    dio: dio,
    pipeline: pipeline ?? FakePipeline(_dataUrl),
    apiKey: apiKey,
    retryDelays: const [Duration.zero, Duration.zero],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OcrRepository.recognizeReceipt（移植 ocrService.test.js）', () {
    test('Key 未配置时抛 OCR_KEY_MISSING 且不发起请求', () async {
      final calls = <RequestOptions>[];
      final repo = _buildRepo([], calls, apiKey: '');

      await expectLater(
        repo.recognizeReceipt('/tmp/receipt.jpg'),
        throwsA(
          isA<OcrException>()
              .having((e) => e.code, 'code', ocrKeyMissingCode)
              .having(
                (e) => e.message,
                'message',
                'Receipt OCR service key not configured',
              ),
        ),
      );
      expect(calls, isEmpty);
    });

    test('正常流：请求体与鉴权头正确，返回归一化字段', () async {
      final calls = <RequestOptions>[];
      final content = jsonEncode({
        'stationName': '特来电 快充站',
        'totalEnergyKwh': 32.16,
        'totalCostYuan': 45.8,
        'durationMinutes': 83,
        'date': '2026-08-28',
        'chargeType': 'fast',
        'confidence': {
          'stationName': 0.9,
          'totalEnergyKwh': 0.95,
          'totalCostYuan': 0.9,
          'durationMinutes': 0.8,
          'date': 0.9,
          'chargeType': 0.7,
        },
      });
      final repo = _buildRepo([_okResponse(content)], calls);

      final result = await repo.recognizeReceipt(
        '/tmp/receipt.jpg',
        now: DateTime(2026, 9, 30),
      );

      final options = calls.single;
      expect(
        options.uri.toString(),
        'https://api.z.ai/api/paas/v4/chat/completions',
      );
      expect(
        (options.headers['Authorization'] as String?) ?? '',
        'Bearer TEST_KEY',
      );
      final body = options.data as Map<dynamic, dynamic>;
      expect(body['model'], 'glm-4.6v-flash');
      expect(body['thinking'], {'type': 'disabled'});
      expect(body['temperature'], ocrTemperature);
      expect(body['max_tokens'], ocrMaxOutputTokens);
      final messages = body['messages'] as List<dynamic>;
      final contentParts =
          (messages[0] as Map<dynamic, dynamic>)['content'] as List<dynamic>;
      final imagePart = contentParts[0] as Map<dynamic, dynamic>;
      expect((imagePart['image_url'] as Map)['url'], _dataUrl);
      expect((contentParts[1] as Map)['type'], 'text');

      expect(result?.cost, '45.8');
      expect(result?.energy, '32.16');
      expect(result?.hours, '1');
      expect(result?.minutes, '23');
      expect(result?.date, '2026-08-28');
      expect(result?.note, '特来电 快充站');
      expect(result?.chargeType, 'fast');
      expect(result?.filledFields, contains('note'));
    });

    test('非 2xx 状态码抛中文错误', () async {
      final calls = <RequestOptions>[];
      final repo = _buildRepo([jsonResponseBody({}, status: 500)], calls);

      await expectLater(
        repo.recognizeReceipt('/tmp/receipt.jpg'),
        throwsA(
          isA<OcrException>().having(
            (e) => e.message,
            'message',
            'Receipt OCR request failed (500)',
          ),
        ),
      );
      expect(calls.length, 1);
    });

    test('HTTP 200 但智谱错误信封时抛中文错误', () async {
      final calls = <RequestOptions>[];
      final repo = _buildRepo([_errorResponse('1210', 'API Key 无效')], calls);

      await expectLater(
        repo.recognizeReceipt('/tmp/receipt.jpg'),
        throwsA(
          isA<OcrException>().having(
            (e) => e.message,
            'message',
            'Receipt recognition failed: API Key 无效',
          ),
        ),
      );
    });

    test('非过载错误码透传且不重试', () async {
      final calls = <RequestOptions>[];
      final repo = _buildRepo([
        _errorResponse('1113', '余额不足', status: 429),
      ], calls);

      await expectLater(
        repo.recognizeReceipt('/tmp/receipt.jpg'),
        throwsA(isA<OcrException>().having((e) => e.code, 'code', '1113')),
      );
      expect(calls.length, 1);
    });

    test('模型输出带 markdown 围栏仍能解析', () async {
      final calls = <RequestOptions>[];
      final repo = _buildRepo([
        _okResponse(
          '```json\n{"totalCostYuan": 18.6, "confidence": '
          '{"totalCostYuan": 0.9}}\n```',
        ),
      ], calls);

      final result = await repo.recognizeReceipt('/tmp/receipt.jpg');

      expect(result?.cost, '18.6');
    });

    test('模型输出非 JSON 时抛「无法识别」中文错误', () async {
      final calls = <RequestOptions>[];
      final repo = _buildRepo([_okResponse('这张图片不是充电小票')], calls);

      await expectLater(
        repo.recognizeReceipt('/tmp/receipt.jpg'),
        throwsA(
          isA<OcrException>().having(
            (e) => e.message,
            'message',
            'Could not read the receipt, please try a clearer photo',
          ),
        ),
      );
    });

    test('图片超过体积上限抛「图片过大」', () async {
      final calls = <RequestOptions>[];
      final bigBase64 = 'A' * (3 * 1024 * 1024);
      final repo = _buildRepo(
        [],
        calls,
        pipeline: FakePipeline('data:image/jpeg;base64,$bigBase64'),
      );

      await expectLater(
        repo.recognizeReceipt('/tmp/big.jpg'),
        throwsA(
          isA<OcrException>().having(
            (e) => e.message,
            'message',
            contains('too large'),
          ),
        ),
      );
      expect(calls, isEmpty);
    });
  });

  group('OcrRepository 过载重试与模型降级', () {
    ResponseBody overload() =>
        _errorResponse('1305', '该模型当前访问量过大，请您稍后再试', status: 429);

    ResponseBody costResponse(String cost) =>
        _okResponse('{"totalCostYuan": $cost}');

    test('过载一次后重试成功：同模型共调用 2 次', () async {
      final calls = <RequestOptions>[];
      final repo = _buildRepo([overload(), costResponse('18.6')], calls);

      final result = await repo.recognizeReceipt('/tmp/receipt.jpg');

      expect(calls.length, 2);
      expect((calls[1].data as Map)['model'], 'glm-4.6v-flash');
      expect(result?.cost, '18.6');
    });

    test('主模型 3 次均过载后降级 glm-4v-flash（无 thinking 字段）', () async {
      final calls = <RequestOptions>[];
      final repo = _buildRepo([
        overload(),
        overload(),
        overload(),
        costResponse('20'),
      ], calls);

      final result = await repo.recognizeReceipt('/tmp/receipt.jpg');

      expect(calls.length, 4);
      final fallbackBody = calls[3].data as Map<dynamic, dynamic>;
      expect(fallbackBody['model'], 'glm-4v-flash');
      expect(fallbackBody.containsKey('thinking'), false);
      expect(result?.cost, '20');
    });

    test('两个模型全部过载时抛「识别服务繁忙」（每模型 3 次共 6 次）', () async {
      final calls = <RequestOptions>[];
      final repo = _buildRepo(
        List<ResponseBody>.generate(6, (_) => overload()),
        calls,
      );

      await expectLater(
        repo.recognizeReceipt('/tmp/receipt.jpg'),
        throwsA(
          isA<OcrException>()
              .having((e) => e.message, 'message', ocrBusyMessage)
              .having((e) => e.code, 'code', overloadErrorCode),
        ),
      );
      expect(calls.length, 6);
    });
  });
}
