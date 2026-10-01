import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/core/storage/local_storage.dart';

/// 键值存储抽象：领域仓储层的唯一持久化出口。
///
/// 语义对齐小程序的 Taro.getStorageSync/setStorageSync：
/// 读同步（SharedPreferences 启动时已初始化）、写异步。
/// 结构化数据以 JSON 字符串存储。
abstract interface class KeyValueStore {
  String? getString(String key);

  /// 读取并 jsonDecode 为 List；缺失 / 解析失败 / 非数组返回 null。
  List<dynamic>? getJsonList(String key);

  /// 读取并 jsonDecode 为 Map；缺失 / 解析失败 / 非对象返回 null。
  Map<String, dynamic>? getJsonMap(String key);

  Future<void> setString(String key, String value);

  /// jsonEncode 后写入；[value] 为 null 时等同 [remove]。
  Future<void> setJson(String key, Object? value);

  /// 读取并 jsonDecode，回调自行判断类型；缺失 / 解析失败返回 null。
  dynamic getJson(String key);

  Future<void> remove(String key);
}

class SharedPrefsKeyValueStore implements KeyValueStore {
  const SharedPrefsKeyValueStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  List<dynamic>? getJsonList(String key) {
    final decoded = _decode(_prefs.getString(key));
    return decoded is List ? decoded : null;
  }

  @override
  Map<String, dynamic>? getJsonMap(String key) {
    final decoded = _decode(_prefs.getString(key));
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  @override
  dynamic getJson(String key) => _decode(_prefs.getString(key));

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> setJson(String key, Object? value) {
    if (value == null) return remove(key);
    return _prefs.setString(key, jsonEncode(value));
  }

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  dynamic _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}

final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => SharedPrefsKeyValueStore(ref.watch(sharedPreferencesProvider)),
);
