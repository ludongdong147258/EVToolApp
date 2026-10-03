/// 充电记录（纯函数）
///
/// 移植自 EVTool（Taro）src/lib/chargeRecords.js（含 vehicles.js 的
/// applyVehicleSnapshotRename / applyVehicleSnapshotRemoval），
/// 逻辑保持一致：输入接受字符串（来自输入框），
/// 任何非法输入返回 null / 空值，绝不抛错。
library;

import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';

/// 充电类型默认标题（记录无备注时列表展示用）
const Map<String, String> typeDefaultTitles = {
  'fast': 'Fast (DC)',
  'home': 'Home (AC)',
};

/// 备注最大长度（与表单 maxlength 一致）
const int noteMaxLength = 100;

/// 充电时长上限（小时），超长视为录入错误
const int maxDurationHours = 72;

/// 地点名称最大长度（与表单 maxlength 一致）
const int locationNameMaxLength = 30;

/// 省/市字段最大长度
const int cityFieldMaxLength = 20;

/// 车辆昵称最大长度（快照字段与表单共用，源自 vehicles.js）
const int vehicleNameMaxLength = 20;

/// GCJ-02 坐标合法范围（中国境内），超出视为录入错误
const double latitudeMin = 3;
const double latitudeMax = 54;
const double longitudeMin = 73;
const double longitudeMax = 136;

/// parseDuration 的非法哨兵值（合法值为正整数或 null）
const int _durationInvalid = -1;

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
String? _truncate(String? value, int maxLength) {
  if (value == null) {
    return null;
  }
  return value.length <= maxLength ? value : value.substring(0, maxLength);
}

/// 规范地点字段（表单与存储守卫共用）：全部可选，任一非法置 null，
/// 经纬度必须成对合法才保留（只有一个合法时两个都丢弃）
class _NormalizedLocation {
  const _NormalizedLocation({
    this.province,
    this.city,
    this.locationName,
    this.latitude,
    this.longitude,
  });

  final String? province;
  final String? city;
  final String? locationName;
  final double? latitude;
  final double? longitude;
}

String? _cleanText(Object? value, int maxLength) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : _truncate(trimmed, maxLength);
}

_NormalizedLocation _normalizeLocationFields({
  Object? province,
  Object? city,
  Object? locationName,
  Object? latitude,
  Object? longitude,
}) {
  final lat = toNumber(latitude);
  final lng = toNumber(longitude);
  double? pairLat;
  double? pairLng;
  if (lat != null && lng != null) {
    final inRange =
        lat >= latitudeMin &&
        lat <= latitudeMax &&
        lng >= longitudeMin &&
        lng <= longitudeMax;
    pairLat = inRange ? lat.toDouble() : null;
    pairLng = inRange ? lng.toDouble() : null;
  }
  return _NormalizedLocation(
    province: _cleanText(province, cityFieldMaxLength),
    city: _cleanText(city, cityFieldMaxLength),
    locationName: _cleanText(locationName, locationNameMaxLength),
    latitude: pairLat,
    longitude: pairLng,
  );
}

/// 充电记录（共享记录模型，不可变）
class ChargeRecord {
  const ChargeRecord({
    this.id = '',
    this.type = '',
    this.date = '',
    this.cost = 0,
    this.energy = 0,
    this.durationMinutes,
    this.note = '',
    this.vehicleId,
    this.vehicleName,
    this.province,
    this.city,
    this.locationName,
    this.latitude,
    this.longitude,
    this.createdAt = 0,
  });

  factory ChargeRecord.fromJson(Map<String, dynamic> json) {
    final duration = toNumber(json['durationMinutes']);
    final createdAt = toNumber(json['createdAt']);
    final vehicleName = json['vehicleName'];
    final location = _normalizeLocationFields(
      province: json['province'],
      city: json['city'],
      locationName: json['locationName'],
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
    return ChargeRecord(
      id: _isTruthy(json['id']) ? json['id'].toString() : '',
      type: json['type'] is String ? json['type'] as String : '',
      date: json['date'] is String ? json['date'] as String : '',
      cost: (toNumber(json['cost']) ?? 0).toDouble(),
      energy: (toNumber(json['energy']) ?? 0).toDouble(),
      durationMinutes: duration != null && duration > 0
          ? duration.round()
          : null,
      note: _truncate((json['note'] ?? '').toString(), noteMaxLength) ?? '',
      vehicleId:
          json['vehicleId'] is String &&
              (json['vehicleId'] as String).isNotEmpty
          ? json['vehicleId'] as String
          : null,
      vehicleName: vehicleName is String && vehicleName.trim().isNotEmpty
          ? _truncate(vehicleName.trim(), vehicleNameMaxLength)
          : null,
      province: location.province,
      city: location.city,
      locationName: location.locationName,
      latitude: location.latitude,
      longitude: location.longitude,
      createdAt: createdAt != null && createdAt.isFinite
          ? (createdAt == 0 ? 0 : createdAt.round())
          : 0,
    );
  }

  final String id;
  final String type;
  final String date;
  final double cost;
  final double energy;
  final int? durationMinutes;
  final String note;
  final String? vehicleId;
  final String? vehicleName;
  final String? province;
  final String? city;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final int createdAt;

  Map<String, dynamic> toJson() {
    final lat = latitude;
    final lng = longitude;
    return {
      'id': id,
      'type': type,
      'date': date,
      'cost': _encodeNum(cost),
      'energy': _encodeNum(energy),
      'durationMinutes': durationMinutes,
      'note': note,
      'vehicleId': vehicleId,
      'vehicleName': vehicleName,
      'province': province,
      'city': city,
      'locationName': locationName,
      'latitude': lat == null ? null : _encodeNum(lat),
      'longitude': lng == null ? null : _encodeNum(lng),
      'createdAt': createdAt,
    };
  }

  /// 整数 double 序列化为 int（与 JS 存储形态一致，68.0 → 68）
  static num _encodeNum(num value) {
    final isWhole = value == value.roundToDouble() && value.abs() < 1e15;
    return isWhole ? value.toInt() : value;
  }

  /// copyWith 未传参哨兵（用于显式置 null 可空字段）
  static const Object _unset = Object();

  /// 局部覆盖；可空字段（durationMinutes 及之后的字段）传 null
  /// 表示显式清空（如 applyVehicleSnapshotRemoval），不传则保持原值
  ChargeRecord copyWith({
    String? id,
    String? type,
    String? date,
    double? cost,
    double? energy,
    Object? durationMinutes = _unset,
    String? note,
    Object? vehicleId = _unset,
    Object? vehicleName = _unset,
    Object? province = _unset,
    Object? city = _unset,
    Object? locationName = _unset,
    Object? latitude = _unset,
    Object? longitude = _unset,
    int? createdAt,
  }) {
    return ChargeRecord(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      cost: cost ?? this.cost,
      energy: energy ?? this.energy,
      durationMinutes: durationMinutes == _unset
          ? this.durationMinutes
          : durationMinutes as int?,
      note: note ?? this.note,
      vehicleId: vehicleId == _unset ? this.vehicleId : vehicleId as String?,
      vehicleName: vehicleName == _unset
          ? this.vehicleName
          : vehicleName as String?,
      province: province == _unset ? this.province : province as String?,
      city: city == _unset ? this.city : city as String?,
      locationName: locationName == _unset
          ? this.locationName
          : locationName as String?,
      latitude: latitude == _unset ? this.latitude : latitude as double?,
      longitude: longitude == _unset ? this.longitude : longitude as double?,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 表单数据（数值字段接受字符串；车辆/地点字段可选）
///
/// 字段名与 JS buildRecordFromForm 的 form 形状一致：
/// { type, date, cost, energy, hours, minutes, note, vehicleId,
///   vehicleName, province, city, locationName, latitude, longitude }
class ChargeRecordForm {
  const ChargeRecordForm({
    this.type,
    this.date,
    this.cost,
    this.energy,
    this.hours,
    this.minutes,
    this.note,
    this.vehicleId,
    this.vehicleName,
    this.province,
    this.city,
    this.locationName,
    this.latitude,
    this.longitude,
  });

  factory ChargeRecordForm.fromMap(Map<String, dynamic> map) {
    return ChargeRecordForm(
      type: map['type'],
      date: map['date'],
      cost: map['cost'],
      energy: map['energy'],
      hours: map['hours'],
      minutes: map['minutes'],
      note: map['note'],
      vehicleId: map['vehicleId'],
      vehicleName: map['vehicleName'],
      province: map['province'],
      city: map['city'],
      locationName: map['locationName'],
      latitude: map['latitude'],
      longitude: map['longitude'],
    );
  }

  final Object? type;
  final Object? date;
  final Object? cost;
  final Object? energy;
  final Object? hours;
  final Object? minutes;
  final Object? note;
  final Object? vehicleId;
  final Object? vehicleName;
  final Object? province;
  final Object? city;
  final Object? locationName;
  final Object? latitude;
  final Object? longitude;

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'date': date,
      'cost': cost,
      'energy': energy,
      'hours': hours,
      'minutes': minutes,
      'note': note,
      'vehicleId': vehicleId,
      'vehicleName': vehicleName,
      'province': province,
      'city': city,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

/// 月度汇总结果（monthKey 非法时为 null 的空汇总）
class MonthSummary {
  const MonthSummary({
    required this.monthKey,
    required this.count,
    required this.totalCost,
    required this.totalEnergy,
    required this.costPerKwh,
  });

  final String? monthKey;
  final int count;
  final double totalCost;
  final double totalEnergy;
  final double? costPerKwh;
}

/// 累计汇总结果
class TotalSummary {
  const TotalSummary({
    required this.count,
    required this.totalCost,
    required this.totalEnergy,
    required this.costPerKwh,
  });

  final int count;
  final double totalCost;
  final double totalEnergy;
  final double? costPerKwh;
}

/// 组合筛选条件（统计页月份 + 类型 + 车辆；地图页复用 year），
/// null 字段不过滤；type 为其他值视为无匹配（返回 []）
class RecordFilters {
  const RecordFilters({this.monthKey, this.year, this.type, this.vehicleId});

  final String? monthKey;
  final String? year;
  final String? type;
  final String? vehicleId;
}

/// 记录日期展示文案：当年省略年份，跨年带年份前缀
///
/// 当年 "Aug 23"；跨年 "Aug 23, 2024"；非法 ""
String formatRecordDate(dynamic dateStr, {DateTime? now}) {
  if (!isValidDateString(dateStr)) {
    return '';
  }
  final current = now ?? DateTime.now();
  final text = dateStr as String;
  final year = int.parse(text.substring(0, 4));
  return year == current.year ? formatMonthDay(text) : formatFullDate(text);
}

/// 时长展示文案
///
/// 85 → "1h 25m"；45 → "45m"；null/0/非法 → ""（视为未记录）
String formatDuration(dynamic minutes) {
  final numValue = toNumber(minutes);
  if (numValue == null || numValue <= 0) {
    return '';
  }
  final total = jsRound(numValue).toInt();
  final hours = total ~/ 60;
  final mins = total % 60;
  if (hours == 0) {
    return '${mins}m';
  }
  if (mins == 0) {
    return '${hours}h';
  }
  return '${hours}h ${mins}m';
}

/// 度电成本（¥/kWh）
///
/// 两位小数；电量无效（≤0/NaN）返回 null
double? calcCostPerKwh(dynamic cost, dynamic energy) {
  final costNum = toNumber(cost);
  final energyNum = toNumber(energy);
  if (costNum == null ||
      energyNum == null ||
      energyNum <= 0 ||
      !costNum.isFinite) {
    return null;
  }
  return toYuan(costNum / energyNum);
}

/// 记录排序：日期降序，同日按 createdAt 降序（新记录在前）
///
/// 返回新数组（不改原数组）；null 输入返回 []
List<ChargeRecord> sortRecordsDesc(List<ChargeRecord>? records) {
  if (records == null) {
    return [];
  }
  return [...records]..sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) {
      return byDate;
    }
    return b.createdAt.compareTo(a.createdAt);
  });
}

/// 累加一组有效记录（cost/energy 均为正数才计入），供月度/累计汇总共用
MonthSummary _accumulateValid(
  List<ChargeRecord> records,
  String monthKey,
  bool Function(ChargeRecord record)? predicate,
) {
  var count = 0;
  var totalCost = 0.0;
  var totalEnergy = 0.0;
  for (final record in records) {
    if (predicate != null && !predicate(record)) {
      continue;
    }
    final cost = toNumber(record.cost);
    final energy = toNumber(record.energy);
    if (cost == null || cost <= 0 || energy == null || energy <= 0) {
      continue;
    }
    count += 1;
    totalCost += cost;
    totalEnergy += energy;
  }
  totalCost = toYuan(totalCost);
  totalEnergy = toYuan(totalEnergy);
  return MonthSummary(
    monthKey: monthKey,
    count: count,
    totalCost: totalCost,
    totalEnergy: totalEnergy,
    costPerKwh: totalEnergy > 0 ? toYuan(totalCost / totalEnergy) : null,
  );
}

/// 月度汇总：只统计目标月内 cost/energy 有效的记录
///
/// monthKey 非法时返回 monthKey 为 null 的空汇总；
/// totalEnergy 为 0 时 costPerKwh 为 null
MonthSummary calcMonthSummary(List<ChargeRecord>? records, dynamic monthKey) {
  if (records == null ||
      monthKey is! String ||
      !monthKeyRe.hasMatch(monthKey)) {
    return const MonthSummary(
      monthKey: null,
      count: 0,
      totalCost: 0,
      totalEnergy: 0,
      costPerKwh: null,
    );
  }
  return _accumulateValid(
    records,
    monthKey,
    (record) => getMonthKey(record.date) == monthKey,
  );
}

/// 累计汇总：全部记录的全量聚合（不按月过滤）
///
/// totalEnergy 为 0 时 costPerKwh 为 null
TotalSummary calcTotalSummary(List<ChargeRecord>? records) {
  if (records == null) {
    return const TotalSummary(
      count: 0,
      totalCost: 0,
      totalEnergy: 0,
      costPerKwh: null,
    );
  }
  final summary = _accumulateValid(records, '', null);
  return TotalSummary(
    count: summary.count,
    totalCost: summary.totalCost,
    totalEnergy: summary.totalEnergy,
    costPerKwh: summary.costPerKwh,
  );
}

/// 月度小结文案（统计页「复制小结」/ 动态分享标题用）
///
/// "Sep 2026 · 12 charges · $320.50 total · avg $0.72/kWh"；
/// 无记录 → "{monthLabel} · No charging records yet"
String buildMonthSummaryText(MonthSummary? summary, String monthLabel) {
  final count = summary?.count ?? 0;
  if (count <= 0) {
    return '$monthLabel · No charging records yet';
  }
  final costPerKwh = summary?.costPerKwh;
  final costPerKwhText = costPerKwh == null ? '--' : formatYuan(costPerKwh);
  return '$monthLabel · $count charges · '
      '${formatMoney(summary?.totalCost)} total · '
      'avg \$$costPerKwhText/kWh';
}

/// 解析时/分表单字段为总分钟数
///
/// 规则：全部留空 → null（未填）；填写的值必须是非负整数且分钟 ≤ 59、
/// 小时 ≤ maxDurationHours；合计为 0 视为未填（null）；
/// 任何字段非法返回 [_durationInvalid]
int? _parseDuration(Object? hours, Object? minutes) {
  final hoursNum = _isEmptyInput(hours) ? 0 : toNumber(hours);
  final minutesNum = _isEmptyInput(minutes) ? 0 : toNumber(minutes);
  final isInvalid =
      hoursNum == null ||
      minutesNum == null ||
      !_isJsInteger(hoursNum) ||
      !_isJsInteger(minutesNum) ||
      hoursNum < 0 ||
      hoursNum > maxDurationHours ||
      minutesNum < 0 ||
      minutesNum > 59;
  if (isInvalid) {
    return _durationInvalid;
  }
  final total = hoursNum * 60 + minutesNum;
  return total > 0 ? total.round() : null;
}

bool _isEmptyInput(Object? value) {
  return value == null || value.toString().trim().isEmpty;
}

/// JS Number.isInteger
bool _isJsInteger(num value) {
  return value.isFinite && value == value.truncateToDouble();
}

/// 表单数据 → 规范充电记录
///
/// type/date/cost/energy/时长 任一非法返回 null；[now] 记录创建时间戳
/// （默认当前时间，测试可注入）
ChargeRecord? buildRecordFromForm(ChargeRecordForm? form, {int? now}) {
  final source = form ?? const ChargeRecordForm();
  if (source.type != 'fast' && source.type != 'home') {
    return null;
  }
  if (!isValidDateString(source.date)) {
    return null;
  }

  final cost = toNumber(source.cost);
  final energy = toNumber(source.energy);
  if (cost == null || cost <= 0 || energy == null || energy <= 0) {
    return null;
  }

  final durationMinutes = _parseDuration(source.hours, source.minutes);
  if (durationMinutes == _durationInvalid) {
    return null;
  }

  final location = _normalizeLocationFields(
    province: source.province,
    city: source.city,
    locationName: source.locationName,
    latitude: source.latitude,
    longitude: source.longitude,
  );
  final createdAt = now ?? DateTime.now().millisecondsSinceEpoch;
  return ChargeRecord(
    id: generateId(nowMs: createdAt),
    type: source.type as String,
    date: source.date as String,
    cost: toYuan(cost),
    energy: toYuan(energy),
    durationMinutes: durationMinutes,
    note: _truncate((source.note ?? '').toString().trim(), noteMaxLength) ?? '',
    vehicleId: _isTruthy(source.vehicleId) ? source.vehicleId.toString() : null,
    vehicleName: _isTruthy(source.vehicleName)
        ? _truncate(source.vehicleName.toString().trim(), vehicleNameMaxLength)
        : null,
    province: location.province,
    city: location.city,
    locationName: location.locationName,
    latitude: location.latitude,
    longitude: location.longitude,
    createdAt: createdAt,
  );
}

/// 存储记录守卫：校验并按字段白名单拷贝（不透传未知字段）
///
/// 任一核心字段非法返回 null
ChargeRecord? normalizeStoredRecord(dynamic raw) {
  if (raw is! Map) {
    return null;
  }
  if (!_isTruthy(raw['id'])) {
    return null;
  }
  if (raw['type'] != 'fast' && raw['type'] != 'home') {
    return null;
  }
  if (!isValidDateString(raw['date'])) {
    return null;
  }

  final cost = toNumber(raw['cost']);
  final energy = toNumber(raw['energy']);
  if (cost == null || cost <= 0 || energy == null || energy <= 0) {
    return null;
  }

  final durationMinutes = toNumber(raw['durationMinutes']);
  final rawVehicleId = raw['vehicleId'];
  final rawVehicleName = raw['vehicleName'];
  final location = _normalizeLocationFields(
    province: raw['province'],
    city: raw['city'],
    locationName: raw['locationName'],
    latitude: raw['latitude'],
    longitude: raw['longitude'],
  );
  final createdAt = toNumber(raw['createdAt']);
  return ChargeRecord(
    id: raw['id'].toString(),
    type: raw['type'] as String,
    date: raw['date'] as String,
    cost: toYuan(cost),
    energy: toYuan(energy),
    durationMinutes: durationMinutes != null && durationMinutes > 0
        ? jsRound(durationMinutes).toInt()
        : null,
    /* 存量记录 note 不 trim（与 JS 口径一致），只截断 */
    note: _truncate((raw['note'] ?? '').toString(), noteMaxLength) ?? '',
    /* 存量记录无车辆/地点字段 → null，展示端按 null 隐藏 */
    vehicleId: rawVehicleId is String && rawVehicleId.isNotEmpty
        ? rawVehicleId
        : null,
    vehicleName: rawVehicleName is String && rawVehicleName.trim().isNotEmpty
        ? _truncate(rawVehicleName.trim(), vehicleNameMaxLength)
        : null,
    province: location.province,
    city: location.city,
    locationName: location.locationName,
    latitude: location.latitude,
    longitude: location.longitude,
    createdAt: createdAt != null && createdAt.isFinite
        ? jsRound(createdAt).toInt()
        : 0,
  );
}

/// 车辆改名：同步刷新关联记录的 vehicleName 快照
///
/// 返回新数组（不改原数组）；非数组输入返回 []。
/// 昵称与表单同口径 trim + 截断到 [vehicleNameMaxLength]。
List<ChargeRecord> applyVehicleSnapshotRename(
  List<ChargeRecord>? records,
  dynamic vehicleId,
  dynamic nextName,
) {
  if (records == null || !_isTruthy(vehicleId)) {
    return records == null ? [] : [...records];
  }
  final name =
      _truncate((nextName ?? '').toString().trim(), vehicleNameMaxLength) ?? '';
  final id = vehicleId.toString();
  return [
    for (final record in records)
      record.vehicleId == id ? record.copyWith(vehicleName: name) : record,
  ];
}

/// 车辆删除：关联记录清除车辆字段（vehicleId/vehicleName → null）
List<ChargeRecord> applyVehicleSnapshotRemoval(
  List<ChargeRecord>? records,
  dynamic vehicleId,
) {
  if (records == null || !_isTruthy(vehicleId)) {
    return records == null ? [] : [...records];
  }
  final id = vehicleId.toString();
  return [
    for (final record in records)
      record.vehicleId == id
          ? record.copyWith(vehicleId: null, vehicleName: null)
          : record,
  ];
}

/// chargeRecords.js 的历史导出名（与 vehicles 快照实现等价）
List<ChargeRecord> applyVehicleRename(
  List<ChargeRecord>? records,
  dynamic vehicleId,
  dynamic nextName,
) {
  return applyVehicleSnapshotRename(records, vehicleId, nextName);
}

/// chargeRecords.js 的历史导出名（与 vehicles 快照实现等价）
List<ChargeRecord> applyVehicleRemoval(
  List<ChargeRecord>? records,
  dynamic vehicleId,
) {
  return applyVehicleSnapshotRemoval(records, vehicleId);
}

/// 有记录的月份列表（降序去重），供统计页月份切换器确定可选范围
///
/// ["2026-08", ...]；空/null → []
List<String> getAvailableMonths(List<ChargeRecord>? records) {
  if (records == null) {
    return [];
  }
  final months = <String>{};
  for (final record in records) {
    final monthKey = getMonthKey(record.date);
    if (monthKey != null) {
      months.add(monthKey);
    }
  }
  final sorted = months.toList()..sort();
  return sorted.reversed.toList();
}

/// 月份 key 平移 n 个月（统计页上/下月切换）。纯算术不实例化 DateTime，
/// 避免时区与日期溢出歧义。
///
/// 正为未来、负为过去；任一输入非法返回 null
String? shiftMonthKey(dynamic monthKey, num? delta) {
  if (monthKey is! String || !monthKeyRe.hasMatch(monthKey)) {
    return null;
  }
  if (delta == null || !_isJsInteger(delta)) {
    return null;
  }
  final year = int.parse(monthKey.substring(0, 4));
  final month = int.parse(monthKey.substring(5));
  final total = year * 12 + (month - 1) + delta.toInt();
  final remainder = total.remainder(12);
  /* floor 除法 + JS 同款截断取余（余数符号随被除数） */
  final nextYear = (total - remainder) ~/ 12;
  final nextMonth = remainder + 1;
  return '$nextYear-${pad2(nextMonth)}';
}

/// 组合筛选记录（统计页月份 + 类型 + 车辆；地图页复用 year）
///
/// 返回新数组（保持原顺序，不改原数组）；非数组输入返回 []
List<ChargeRecord> filterRecords(
  List<ChargeRecord>? records,
  RecordFilters? filters,
) {
  if (records == null) {
    return [];
  }
  final filter = filters ?? const RecordFilters();
  final type = filter.type;
  if (type != null && type != 'fast' && type != 'home') {
    return [];
  }
  return [
    for (final record in records)
      if (_matchesFilters(record, filter)) record,
  ];
}

bool _matchesFilters(ChargeRecord record, RecordFilters filter) {
  if (_isTruthy(filter.monthKey) &&
      getMonthKey(record.date) != filter.monthKey) {
    return false;
  }
  /* 与 JS slice(0, 4) 同口径：短于 4 位时取整串（必不等于年份） */
  final yearPrefix = record.date.length >= 4
      ? record.date.substring(0, 4)
      : record.date;
  if (_isTruthy(filter.year) && yearPrefix != filter.year) {
    return false;
  }
  if (_isTruthy(filter.type) && record.type != filter.type) {
    return false;
  }
  if (_isTruthy(filter.vehicleId) && record.vehicleId != filter.vehicleId) {
    return false;
  }
  return true;
}
