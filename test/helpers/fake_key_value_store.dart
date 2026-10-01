import 'dart:convert';

import 'package:ev_tool_app/core/storage/key_value_store.dart';

/// 测试用内存 KeyValueStore。
class FakeKeyValueStore implements KeyValueStore {
  final Map<String, String> _store = {};

  @override
  String? getString(String key) => _store[key];

  @override
  List<dynamic>? getJsonList(String key) {
    final decoded = _decode(_store[key]);
    return decoded is List ? decoded : null;
  }

  @override
  Map<String, dynamic>? getJsonMap(String key) {
    final decoded = _decode(_store[key]);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  @override
  dynamic getJson(String key) => _decode(_store[key]);

  @override
  Future<void> setString(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> setJson(String key, Object? value) async {
    if (value == null) {
      await remove(key);
      return;
    }
    _store[key] = jsonEncode(value);
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }

  /// 直接写入原始字符串（构造损坏数据用）。
  void setRaw(String key, String value) => _store[key] = value;

  dynamic _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}
