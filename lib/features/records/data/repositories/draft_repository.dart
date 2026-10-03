import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/features/records/data/repositories/record_repository.dart';

/// 表单草稿仓储（移植小程序 draftService.js）。
///
/// 存储key `formDraft:<page>`，值为 JSON 字符串；读容错（字符串/对象均接受），
/// 写失败抛 [StorageException]。
class DraftRepository {
  DraftRepository(this._kv);

  static const String keyPrefix = 'formDraft:';
  final KeyValueStore _kv;

  Map<String, dynamic>? getDraft(String page) {
    try {
      final raw = _kv.getString('$keyPrefix$page');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> saveDraft(String page, Map<String, dynamic> draft) async {
    try {
      await _kv.setString('$keyPrefix$page', jsonEncode(draft));
    } on Exception catch (e) {
      appLogger.e('Failed to save draft', error: e);
      throw const StorageException('Failed to save draft');
    }
  }

  /// 清除草稿（尽力而为，失败不抛）。
  Future<void> clearDraft(String page) async {
    try {
      await _kv.remove('$keyPrefix$page');
    } on Exception catch (e) {
      appLogger.w('Failed to clear draft', error: e);
    }
  }
}

final draftRepositoryProvider = Provider<DraftRepository>(
  (ref) => DraftRepository(ref.watch(keyValueStoreProvider)),
);
