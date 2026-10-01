import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/constants/env.dart';
import 'package:ev_tool_app/core/domain/ocr_receipt.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/features/ocr/data/receipt_image_pipeline.dart';

/// OCR 专用异常：[code] 为智谱错误码（如 "1305"），供重试/降级判断；
/// Key 未配置时 code 为 [ocrKeyMissingCode]。
class OcrException implements Exception {
  const OcrException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Key 未配置错误码（调用方据此隐藏入口）
const String ocrKeyMissingCode = 'OCR_KEY_MISSING';

/// 智谱开放平台地址
const String ocrApiBase = 'https://open.bigmodel.cn';

/// 智谱「模型访问量过大」错误码：唯一可重试/可降级的错误
const String overloadErrorCode = '1305';

/// 同模型重试间隔（指数退避），首试之外最多重试这么多次
const List<Duration> overloadRetryDelays = [
  Duration(milliseconds: 800),
  Duration(milliseconds: 1600),
];

/// 全部候选模型过载后的用户文案
const String ocrBusyMessage = '识别服务繁忙，请稍后再试';

/// 生成参数：低温度保证稳定抽取
const double ocrTemperature = 0.1;

/// 小票字段 JSON 输出约 200 token，512 上限防 runaway 生成拖慢响应
const int ocrMaxOutputTokens = 512;

/// base64 图片体积上限（估算原始字节），超过则要求重拍
const int ocrMaxImageBytes = 2 * 1024 * 1024;

/// 模型候选（主模型 glm-4v-flash，过载降级 glm-4.6v-flash）
class _OcrModel {
  const _OcrModel(this.name, this.supportsThinking);

  final String name;
  final bool supportsThinking;
}

const List<_OcrModel> _ocrModelChain = [
  _OcrModel('glm-4v-flash', false),
  _OcrModel('glm-4.6v-flash', true),
];

/// 充电小票 OCR 识别仓储（移植小程序 src/services/ocrService.js）。
///
/// 图片 → base64 → 智谱 GLM chat/completions → 结构化 JSON →
/// normalizeReceiptResult 归一化。不复用dioProvider：第三方接口走独立
/// Bearer Key，不挂本站用户 token，也不处理 401 刷新链路。
/// 过载容错：错误码 1305 同模型指数退避重试，耗尽降级备用模型，
/// 全部失败抛「识别服务繁忙」。
class OcrRepository {
  OcrRepository({
    required Dio dio,
    required ReceiptImagePipeline pipeline,
    String? apiKey,
    List<Duration> retryDelays = overloadRetryDelays,
  }) : _dio = dio,
       _pipeline = pipeline,
       _apiKey = apiKey,
       _retryDelays = retryDelays;

  final Dio _dio;
  final ReceiptImagePipeline _pipeline;
  final String? _apiKey;
  final List<Duration> _retryDelays;

  /// 识别门面：本地图片路径 → 预压缩 → base64 → 识别归一化。
  ///
  /// [now] 可注入当前时间（归一化日期校验用，测试用）。
  ///
  /// 抛 [OcrException]：Key 未配置（code [ocrKeyMissingCode]）、
  /// 图片过大、网络/模型输出异常（中文文案）。
  Future<ReceiptResult?> recognizeReceipt(
    String imagePath, {
    DateTime? now,
  }) async {
    final key = _apiKey ?? '';
    if (key.isEmpty) {
      throw const OcrException('小票识别服务 Key 未配置', code: ocrKeyMissingCode);
    }
    final dataUrl = await _prepareDataUrl(imagePath);
    final body = await _requestWithModelFallback(key, dataUrl);
    final choices = body['choices'];
    final message = choices is List && choices.isNotEmpty && choices[0] is Map
        ? choices[0] as Map
        : null;
    final rawContent = message?['message'] is Map
        ? (message?['message'] as Map)['content']
        : null;
    final parsed = extractJsonBlock(rawContent is String ? rawContent : null);
    if (parsed == null) {
      appLogger.w('小票识别输出无法解析为 JSON');
      throw const OcrException('无法识别小票内容，请换一张更清晰的照片');
    }
    return normalizeReceiptResult(parsed, now: now);
  }

  /// 图片预处理 + 体积守卫（base64 长度 × 3/4 估算原始字节）。
  Future<String> _prepareDataUrl(String imagePath) async {
    final dataUrl = await _pipeline.toBase64DataUrl(imagePath);
    final base64 = dataUrl.split(',').lastOrNull ?? '';
    if (base64.length * 3 / 4 > ocrMaxImageBytes) {
      throw const OcrException('图片过大，请重新拍摄或选择更小的图片');
    }
    return dataUrl;
  }

  /// 模型降级链：依次尝试候选模型（各自带退避重试），
  /// 过载耗尽换下一个模型，非过载错误立即抛出，全过载抛繁忙。
  Future<Map<String, dynamic>> _requestWithModelFallback(
    String apiKey,
    String dataUrl,
  ) async {
    for (final model in _ocrModelChain) {
      try {
        return await _requestWithRetry(apiKey, _buildBody(model, dataUrl));
      } on OcrException catch (e) {
        if (e.code != overloadErrorCode) {
          rethrow;
        }
        appLogger.w('模型 ${model.name} 过载：${e.message}');
      }
    }
    throw const OcrException(ocrBusyMessage, code: overloadErrorCode);
  }

  Map<String, dynamic> _buildBody(_OcrModel model, String dataUrl) {
    return <String, dynamic>{
      'model': model.name,
      // 显式关闭思考模式（仅思考系模型支持）：结构化抽取无需深层推理，
      // 避免推理 token 消耗 max_tokens 预算导致 content 为空、解析失败
      if (model.supportsThinking)
        'thinking': <String, String>{'type': 'disabled'},
      'temperature': ocrTemperature,
      'max_tokens': ocrMaxOutputTokens,
      'messages': [
        <String, dynamic>{
          'role': 'user',
          'content': [
            <String, dynamic>{
              'type': 'image_url',
              'image_url': <String, String>{'url': dataUrl},
            },
            <String, dynamic>{'type': 'text', 'text': ocrPrompt},
          ],
        },
      ],
    };
  }

  /// 带退避重试的请求：仅对过载错误码（1305）重试，其余立即抛出。
  Future<Map<String, dynamic>> _requestWithRetry(
    String apiKey,
    Map<String, dynamic> body,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt <= _retryDelays.length; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_retryDelays[attempt - 1]);
      }
      try {
        return await _chat(apiKey, body);
      } on OcrException catch (e) {
        if (e.code != overloadErrorCode) {
          rethrow;
        }
        lastError = e;
      }
    }
    throw lastError is OcrException
        ? lastError
        : const OcrException(ocrBusyMessage, code: overloadErrorCode);
  }

  /// POST chat/completions：非 2xx 或 HTTP 200 但 body.error（智谱错误
  /// 信封）均抛中文 [OcrException]，错误码挂 exception 的 code。
  Future<Map<String, dynamic>> _chat(
    String apiKey,
    Map<String, dynamic> body,
  ) async {
    Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '/api/paas/v4/chat/completions',
        data: body,
        options: Options(
          headers: <String, String>{'Authorization': 'Bearer $apiKey'},
        ),
      );
    } on DioException catch (e) {
      throw _toRequestError(e);
    }
    final data = response.data;
    if (data is Map && data['error'] is Map) {
      throw _envelopeError(Map<String, dynamic>.from(data['error'] as Map));
    }
    if (data is! Map) {
      throw const OcrException('小票识别服务响应异常');
    }
    return Map<String, dynamic>.from(data);
  }

  OcrException _envelopeError(Map<String, dynamic> apiError) {
    return OcrException(
      '小票识别失败：${apiError['message'] ?? '未知错误'}',
      code: apiError['code']?.toString(),
    );
  }

  OcrException _toRequestError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      return _envelopeError(Map<String, dynamic>.from(data['error'] as Map));
    }
    return OcrException('小票识别服务请求失败（${e.response?.statusCode}）');
  }
}

/// OCR 专用 Dio（独立 Bearer Key，60s 超时，不挂拦截器）。
final ocrDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ocrApiBase,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

/// OCR 服务是否可用（智谱 Key 是否配置；入口据此显隐）。
final ocrAvailableProvider = Provider<bool>((ref) => Env.hasZhipuKey);

final ocrRepositoryProvider = Provider<OcrRepository>(
  (ref) => OcrRepository(
    dio: ref.watch(ocrDioProvider),
    pipeline: const FlutterImageCompressPipeline(),
    apiKey: Env.zhipuKey,
  ),
);
