import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:ev_tool_app/core/domain/ocr_receipt.dart';
import 'package:ev_tool_app/core/utils/logger.dart';

/// 识别图片最长边（px）：小票文字够用，控制上行 payload 与服务端预处理耗时
const int ocrImageMaxSide = 1280;

/// JPEG 压缩质量（0-100）
const int ocrJpegQuality = 60;

/// 小票图片预处理接口（测试可注入假实现）。
///
/// 职责：读文件 → 解码尺寸 → 等比缩放到 [ocrImageMaxSide] +
/// JPEG 质量压缩 → base64 data URL（"data:image/jpeg;base64,..."）。
abstract interface class ReceiptImagePipeline {
  Future<String> toBase64DataUrl(String imagePath);
}

/// 生产实现：flutter_image_compress 压缩管线。
///
/// 解码 / 压缩任一步失败均回退原图（2MB 守卫在仓储层兜底）。
class FlutterImageCompressPipeline implements ReceiptImagePipeline {
  const FlutterImageCompressPipeline();

  @override
  Future<String> toBase64DataUrl(String imagePath) async {
    final bytes = await _readBytes(imagePath);
    if (bytes == null) {
      throw const OSError('图片读取失败，请重试');
    }
    try {
      final size = await _decodeSize(bytes);
      final target = computeTargetSize(
        size?['width'],
        size?['height'],
        ocrImageMaxSide,
      );
      final compressed = await FlutterImageCompress.compressWithFile(
        imagePath,
        minWidth: target.needsScale ? target.targetWidth.toInt() : 10000,
        minHeight: target.needsScale ? target.targetHeight.toInt() : 10000,
        quality: ocrJpegQuality,
        format: CompressFormat.jpeg,
      );
      final result = compressed ?? bytes;
      return 'data:image/jpeg;base64,${base64Encode(result)}';
    } on Exception catch (e) {
      appLogger.w('识别图片预压缩失败，回退原图：$e');
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }
  }

  Future<Uint8List?> _readBytes(String imagePath) async {
    try {
      return await File(imagePath).readAsBytes();
    } on Exception catch (e) {
      appLogger.w('识别图片读取失败：$e');
      return null;
    }
  }

  Future<Map<String, double>?> _decodeSize(Uint8List bytes) async {
    try {
      final image = await decodeImageFromList(bytes);
      final size = <String, double>{
        'width': image.width.toDouble(),
        'height': image.height.toDouble(),
      };
      image.dispose();
      return size;
    } on Exception catch (e) {
      appLogger.w('识别图片尺寸解码失败：$e');
      return null;
    }
  }
}
