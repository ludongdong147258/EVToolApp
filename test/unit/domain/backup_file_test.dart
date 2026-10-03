/// backup_file.dart 单测（移植自 src/lib/__tests__/backupFile.test.js）
library;

import 'package:ev_tool_app/core/domain/backup_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isClipboardOverflow 剪贴板阈值判断', () {
    test('长度恰好等于阈值不拦截', () {
      expect(isClipboardOverflow('x' * clipboardExportMaxLength), isFalse);
    });

    test('长度超出阈值一个字符即拦截', () {
      expect(isClipboardOverflow('x' * (clipboardExportMaxLength + 1)), isTrue);
    });

    test('非字符串与空串不拦截', () {
      expect(isClipboardOverflow(null), isFalse);
      expect(isClipboardOverflow(12345), isFalse);
      expect(isClipboardOverflow(''), isFalse);
    });
  });

  group('buildBackupFileName 备份文件名', () {
    test('格式为 前缀-日期.json', () {
      // JS new Date(2026, 9, 1) 月份 0 基 → 2026-10-01
      expect(
        buildBackupFileName(DateTime(2026, 10, 1)),
        'EVTool-Backup-2026-10-01.json',
      );
    });

    test('个位月日补零', () {
      // JS new Date(2026, 0, 5) → 2026-01-05
      expect(
        buildBackupFileName(DateTime(2026, 1, 5)),
        'EVTool-Backup-2026-01-05.json',
      );
    });
  });

  group('formatPayloadSize 载荷大小文案', () {
    test('小于 1MB 按 KB 展示一位小数', () {
      expect(formatPayloadSize('x' * 512), '0.5 KB');
      expect(formatPayloadSize('x' * 36864), '36.0 KB');
    });

    test('达到 1MB 按 MB 展示', () {
      final onePointFiveMb = (1.5 * 1024 * 1024).round();
      expect(formatPayloadSize('x' * onePointFiveMb), '1.5 MB');
    });

    test('非字符串按 0 处理', () {
      expect(formatPayloadSize(null), '0.0 KB');
    });
  });

  group('isJsonFilePath json 路径校验', () {
    test('接受 .json 结尾路径，大小写不敏感', () {
      expect(isJsonFilePath('wxfile://tmp/EVTool-Backup.json'), isTrue);
      expect(isJsonFilePath('/tmp/backup.JSON'), isTrue);
    });

    test('拒绝非 json 与非字符串', () {
      expect(isJsonFilePath('/tmp/backup.txt'), isFalse);
      expect(isJsonFilePath('json'), isFalse);
      expect(isJsonFilePath(null), isFalse);
      expect(isJsonFilePath(123), isFalse);
    });
  });

  group('isPrivacyApiError 隐私接口错误识别', () {
    test('errMsg 含 privacy（未声明 errno 112 / 未授权）识别为隐私错误', () {
      expect(
        isPrivacyApiError(<String, dynamic>{
          'errMsg':
              'getClipboardData:fail api scope is not declared in the privacy agreement',
          'errno': 112,
        }),
        isTrue,
      );
      expect(
        isPrivacyApiError(<String, dynamic>{
          'errMsg':
              'chooseMessageFile:fail privacy permission is not authorized',
        }),
        isTrue,
      );
    });

    test('普通错误不误判', () {
      expect(
        isPrivacyApiError(<String, dynamic>{'errMsg': 'setClipboardData:fail'}),
        isFalse,
      );
      // JS 测试中的 Error 对象在 Dart 下对应 Exception
      expect(isPrivacyApiError(Exception('request:fail timeout')), isFalse);
    });

    test('空值/非错误输入不误判', () {
      expect(isPrivacyApiError(null), isFalse);
    });
  });
}
