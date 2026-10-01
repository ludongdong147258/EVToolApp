/// 备份文件工具（纯函数）
///
/// 移植自 EVTool 小程序 src/lib/backupFile.js。
/// 剪贴板导出长度守卫、备份文件名、载荷大小文案与备份文件路径校验。
library;

import 'package:ev_tool_app/core/domain/date_utils.dart';

/// 剪贴板导出文本长度上限（约 32KB）：
/// 安卓真机超出后 setClipboardData 不可靠
const int clipboardExportMaxLength = 32 * 1024;

/// 备份文件名前缀
const String backupFilePrefix = 'EVTool备份';

/// 备份文本是否超出剪贴板可靠长度
///
/// 非字符串（含空串）返回 false，不拦截。
bool isClipboardOverflow(Object? text) {
  return text is String && text.length > clipboardExportMaxLength;
}

/// 备份文件名：`EVTool备份-2026-10-01.json`
///
/// 同日重复导出同名覆盖，最新备份胜出。
String buildBackupFileName(DateTime now) {
  return '$backupFilePrefix-${getTodayStr(now: now)}.json';
}

/// 载荷大小展示文案："35.6 KB" / "1.2 MB"（提示文案用）
String formatPayloadSize(Object? text) {
  final length = text is String ? text.length : 0;
  final kb = length / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(1)} KB';
  }
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}

/// 路径是否 .json 备份文件（文件选择结果防御性校验，大小写不敏感）
bool isJsonFilePath(Object? path) {
  return path is String && path.toLowerCase().endsWith('.json');
}

/// 是否隐私接口未声明/未授权错误
///
/// errMsg/message 含 "privacy"（errno 112 未声明 / 未授权）时识别为隐私错误。
bool isPrivacyApiError(Object? err) {
  String message = '';
  if (err is Map) {
    final msg = err['errMsg'] ?? err['message'];
    message = msg == null ? '' : msg.toString();
  } else if (err != null) {
    message = err.toString();
  }
  return RegExp('privacy', caseSensitive: false).hasMatch(message);
}
