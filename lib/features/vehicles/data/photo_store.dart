import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ev_tool_app/core/utils/logger.dart';

/// 照片持久化存储（移植小程序 Taro.saveFile 的职责）。
///
/// 照片统一落到 `<appDocs>/vehicle_photos/`（或调用方指定的目录），
/// 业务数据（Vehicle.photoPath / UserProfile.avatarUrl）只保存裸文件名，
/// 展示时经 [resolvePath] 还原完整路径；文件随业务删除尽力清理。
class PhotoStoreException implements Exception {
  const PhotoStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 压缩写入函数签名（测试可注入替身）。
typedef PhotoCompressor =
    Future<Object?> Function(String sourcePath, String targetPath);

/// 压缩目标最长边（px）。
const int photoMaxDimension = 1280;

/// 压缩质量（0-100）。
const int photoQuality = 85;

/// 默认压缩实现：jpeg，最长边 [photoMaxDimension]，质量 [photoQuality]。
Future<Object?> _defaultCompressor(String sourcePath, String targetPath) {
  return FlutterImageCompress.compressAndGetFile(
    sourcePath,
    targetPath,
    minWidth: photoMaxDimension,
    minHeight: photoMaxDimension,
    quality: photoQuality,
    format: CompressFormat.jpeg,
  );
}

class PhotoStore {
  PhotoStore(this._directory, {PhotoCompressor? compressor})
    : _compressor = compressor ?? _defaultCompressor;

  /// 照片所在目录（懒创建）。
  final Directory _directory;
  final PhotoCompressor _compressor;

  /// 保存照片：压缩后写入 `<目录>/<key>_<毫秒时间戳>.jpg`。
  ///
  /// 返回裸文件名（供业务字段存储）；压缩失败降级为原图拷贝。
  Future<String> save({required String sourcePath, required String key}) async {
    final source = sourcePath.trim();
    if (source.isEmpty) {
      throw const PhotoStoreException('照片路径无效');
    }
    await _directory.create(recursive: true);
    // 同毫秒内多次保存会撞名（时间戳相同）：存在即追加序号直至唯一
    var filename = '${key}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    var targetPath = resolvePath(filename);
    var seq = 0;
    while (File(targetPath).existsSync()) {
      seq++;
      filename = '${key}_${DateTime.now().millisecondsSinceEpoch}_$seq.jpg';
      targetPath = resolvePath(filename);
    }
    Object? compressed;
    try {
      compressed = await _compressor(source, targetPath);
    } on Exception catch (e) {
      appLogger.w('压缩照片失败，降级为原图拷贝', error: e);
    }
    if (compressed == null) {
      await File(source).copy(targetPath);
    }
    return filename;
  }

  /// 裸文件名 → 完整路径（空文件名返回空串）。
  String resolvePath(String filename) =>
      filename.isEmpty ? '' : '${_directory.path}/$filename';

  /// 照片文件是否已落盘（UI 渲染前的同步守卫）。
  bool exists(String filename) =>
      filename.isNotEmpty && File(resolvePath(filename)).existsSync();

  /// 删除照片文件（尽力而为，失败仅记录日志）。
  Future<void> delete(String filename) async {
    if (filename.isEmpty) return;
    try {
      final file = File(resolvePath(filename));
      if (await file.exists()) {
        await file.delete();
      }
    } on Exception catch (e) {
      appLogger.w('清理照片文件失败', error: e);
    }
  }
}

/// 车辆照片存储：`<appDocs>/vehicle_photos`。
final photoStoreProvider = FutureProvider<PhotoStore>((ref) async {
  final docs = await getApplicationDocumentsDirectory();
  return PhotoStore(Directory('${docs.path}/vehicle_photos'));
});
