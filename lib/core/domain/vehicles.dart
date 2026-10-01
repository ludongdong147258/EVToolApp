/// 车辆档案（纯函数）
///
/// 移植自 EVTool 小程序 src/lib/vehicles.js。
/// 覆盖「我的车辆」所需的全部无副作用逻辑：
/// 昵称/电池容量校验、表单 → 规范车辆、存储脏数据守卫、
/// 排序与默认车不变量修复。
/// 车辆改名/删除时对充电记录与养车支出两个台账的
/// vehicleName 快照同步分别由 charge_records.dart /
/// maintenance_costs.dart 以同口径实现。
/// 约定：输入接受字符串（来自输入框），任何非法输入返回 null / 空值，绝不抛错。
library;

import 'package:ev_tool_app/core/domain/numbers.dart';

/// 车辆昵称最大长度（与表单 maxlength 一致）
const int vehicleNameMaxLength = 20;

/// 车辆备注最大长度（与表单 maxlength 一致）
const int vehicleNoteMaxLength = 100;

/// 电池容量下限（kWh）
const double batteryMin = 15;

/// 电池容量上限（kWh）
const double batteryMax = 200;

/// 车辆照片路径最大长度（防脏数据）
const int photoPathMaxLength = 500;

/// 车辆（不可变）
class Vehicle {
  const Vehicle({
    required this.id,
    required this.name,
    required this.battery,
    required this.note,
    required this.photoPath,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 存储脏数据守卫（id/昵称/容量任一非法返回 null，绝不抛错）
  static Vehicle? fromJson(Map<String, dynamic>? json) =>
      normalizeStoredVehicle(json);

  /// 车辆 id
  final String id;

  /// 昵称
  final String name;

  /// 电池容量（kWh，一位小数）
  final double battery;

  /// 备注
  final String note;

  /// 照片本地路径（无照片为空串）
  final String photoPath;

  /// 是否默认车辆
  final bool isDefault;

  /// 创建时间戳（毫秒）
  final int createdAt;

  /// 更新时间戳（毫秒）
  final int updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'battery': battery,
    'note': note,
    'photoPath': photoPath,
    'isDefault': isDefault,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  /// 返回仅替换部分字段的新车辆（不可变）
  Vehicle copyWith({
    String? id,
    String? name,
    double? battery,
    String? note,
    String? photoPath,
    bool? isDefault,
    int? createdAt,
    int? updatedAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      battery: battery ?? this.battery,
      note: note ?? this.note,
      photoPath: photoPath ?? this.photoPath,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// JS 真值判定（null / false / 0 / NaN / "" 为假）
bool _isTruthy(Object? value) {
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return !value.isNaN && value != 0;
  }
  if (value is String) {
    return value.isNotEmpty;
  }
  return true;
}

/// JS String.slice(0, maxLength)：按 UTF-16 码元截断
String _truncate(String value, int maxLength) {
  return value.length <= maxLength ? value : value.substring(0, maxLength);
}

/// 电池容量取整到一位小数（如 23.68 → 23.7）
double _toBattery(double value) => jsRound(value * 10) / 10;

/// 车辆昵称规范化
///
/// trim 后截断到 [vehicleNameMaxLength]；空白或非字符串返回 null。
String? normalizeVehicleName(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final name = _truncate(raw.trim(), vehicleNameMaxLength);
  return name.isEmpty ? null : name;
}

/// 车辆照片本地路径规范化
///
/// 非字符串或空白返回 ''（无照片），超长截断防脏数据撑爆 storage。
String normalizePhotoPath(Object? raw) {
  if (raw is! String) {
    return '';
  }
  final trimmed = raw.trim();
  return trimmed.isEmpty ? '' : _truncate(trimmed, photoPathMaxLength);
}

/// 电池容量解析（kWh）
///
/// 接受字符串（来自输入框）；返回 [batteryMin]–[batteryMax] 范围内的
/// 一位小数，越界/非法返回 null。
double? parseBattery(Object? raw) {
  final num = toNumber(raw);
  if (num == null || num < batteryMin || num > batteryMax) {
    return null;
  }
  return _toBattery(num.toDouble());
}

/// 车辆表单数据（battery 接受字符串，来自输入框）
class VehicleForm {
  const VehicleForm({this.name, this.battery, this.note, this.photoPath});

  /// 昵称
  final Object? name;

  /// 电池容量
  final Object? battery;

  /// 备注
  final Object? note;

  /// 照片路径
  final Object? photoPath;
}

/// 表单数据 → 规范车辆
///
/// 昵称或容量任一非法返回 null（photoPath 为选填不影响）。
Vehicle? buildVehicleFromForm(
  VehicleForm? form,
  int now, {
  bool isDefault = false,
}) {
  final source = form ?? const VehicleForm();
  final name = normalizeVehicleName(source.name);
  final battery = parseBattery(source.battery);
  if (name == null || battery == null) {
    return null;
  }
  return Vehicle(
    id: generateId(nowMs: now),
    name: name,
    battery: battery,
    note: _truncate(_stringify(source.note).trim(), vehicleNoteMaxLength),
    photoPath: normalizePhotoPath(source.photoPath),
    isDefault: isDefault,
    createdAt: now,
    updatedAt: now,
  );
}

/// 存储车辆守卫：校验并按字段白名单拷贝（不透传未知字段）
///
/// id/昵称/容量任一非法返回 null。
Vehicle? normalizeStoredVehicle(Map<String, dynamic>? raw) {
  if (raw == null || !_isTruthy(raw['id'])) {
    return null;
  }
  final name = normalizeVehicleName(raw['name']);
  final battery = parseBattery(raw['battery']);
  if (name == null || battery == null) {
    return null;
  }
  final createdAt = _timestampOrZero(raw['createdAt']);
  final updatedAt = _timestampOrZero(raw['updatedAt']);
  return Vehicle(
    id: raw['id'].toString(),
    name: name,
    battery: battery,
    note: _truncate(_stringify(raw['note']), vehicleNoteMaxLength),
    photoPath: normalizePhotoPath(raw['photoPath']),
    isDefault: _isTruthy(raw['isDefault']),
    createdAt: createdAt,
    updatedAt: updatedAt == 0 ? createdAt : updatedAt,
  );
}

/// 车辆排序：默认车置顶，其余按 createdAt 降序（新添加靠前）
///
/// 返回新数组（不改原数组）；非数组输入返回 []。
List<Vehicle> sortVehicles(List<Vehicle>? vehicles) {
  if (vehicles == null) {
    return const <Vehicle>[];
  }
  final sorted = List<Vehicle>.of(vehicles);
  sorted.sort((a, b) {
    if (a.isDefault != b.isDefault) {
      return a.isDefault ? -1 : 1;
    }
    return b.createdAt.compareTo(a.createdAt);
  });
  return sorted;
}

/// 修复默认车不变量：列表非空 ⇒ 恰有一辆默认车
///
/// 无默认时把排序后首辆置为默认；多辆默认时只保留排序最前的一辆。
List<Vehicle> ensureSingleDefault(List<Vehicle>? vehicles) {
  if (vehicles == null || vehicles.isEmpty) {
    return const <Vehicle>[];
  }
  final sorted = sortVehicles(vehicles);
  var keptIndex = sorted.indexWhere((item) => item.isDefault);
  if (keptIndex == -1) {
    keptIndex = 0;
  }
  return <Vehicle>[
    for (var index = 0; index < sorted.length; index += 1)
      sorted[index].copyWith(isDefault: index == keptIndex),
  ];
}

/// JS String(value ?? "") 的等价转换（null → ""）
String _stringify(Object? value) => value == null ? '' : value.toString();

/// 时间戳守卫：非法 / 0 归 0（与 JS toNumber(x) || 0 同口径）
int _timestampOrZero(Object? value) {
  final num = toNumber(value);
  if (num == null || num == 0) {
    return 0;
  }
  return jsRound(num).toInt();
}
