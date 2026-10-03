/// charge_records.dart 单测（移植自 src/lib/__tests__/chargeRecords.test.js）
library;

import 'package:ev_tool_app/core/domain/charge_records.dart';
// formatMonthLabel 现由 date_utils 提供（charge_records 本地副本已删除）。
import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:flutter_test/flutter_test.dart';

ChargeRecord recordOf({
  String id = '',
  String type = '',
  String date = '',
  double cost = 0,
  double energy = 0,
  int? durationMinutes,
  String note = '',
  String? vehicleId,
  String? vehicleName,
  int createdAt = 0,
}) {
  return ChargeRecord(
    id: id,
    type: type,
    date: date,
    cost: cost,
    energy: energy,
    durationMinutes: durationMinutes,
    note: note,
    vehicleId: vehicleId,
    vehicleName: vehicleName,
    createdAt: createdAt,
  );
}

Map<String, dynamic> baseRaw([Map<String, dynamic> overrides = const {}]) {
  return <String, dynamic>{
    'id': 'r1',
    'type': 'fast',
    'date': '2026-08-23',
    'cost': 68,
    'energy': 45,
    'durationMinutes': 85,
    'note': 'x',
    'createdAt': 1000,
    ...overrides,
  };
}

void main() {
  group('getTodayStr / getMonthKey / getCurrentMonthKey 日期工具', () {
    test('getTodayStr 输出 YYYY-MM-DD 并补零', () {
      // Arrange：2026 年 8 月 3 日（JS 月份 0 基 → Dart 1 基）
      final now = DateTime(2026, 8, 3);

      // Act
      final result = getTodayStr(now: now);

      // Assert
      expect(result, '2026-08-03');
    });

    test('getMonthKey 截取年月，非法输入返回 null', () {
      expect(getMonthKey('2026-08-23'), '2026-08');
      expect(getMonthKey('2024-13-01'), '2024-13'); // 只切割不校验历法
      expect(getMonthKey('abc'), isNull);
      expect(getMonthKey(123), isNull);
      expect(getMonthKey(null), isNull);
    });

    test('getCurrentMonthKey 返回当前年月', () {
      final now = DateTime(2026, 1, 15);
      expect(getCurrentMonthKey(now: now), '2026-01');
    });
  });

  group('formatYuan 金额格式化', () {
    test('保留两位小数', () {
      expect(formatYuan(345.5), '345.50');
      expect(formatYuan(0), '0.00');
    });

    test('千分位分隔整数部分', () {
      final result = formatYuan(1234567.891);
      expect(result, '1,234,567.89');
    });

    test('接受字符串输入，非法值返回 0.00', () {
      expect(formatYuan('88.4'), '88.40');
      expect(formatYuan('abc'), '0.00');
    });
  });

  group('formatRecordDate 记录日期展示', () {
    test('当年日期省略年份', () {
      final now = DateTime(2026, 8, 23);
      expect(formatRecordDate('2026-08-01', now: now), 'Aug 1');
      expect(formatRecordDate('2026-01-15', now: now), 'Jan 15');
    });

    test('跨年日期带年份前缀', () {
      final now = DateTime(2026, 8, 23);
      expect(formatRecordDate('2024-10-24', now: now), 'Oct 24, 2024');
    });

    test('非法输入返回空串', () {
      expect(formatRecordDate('abc'), '');
      expect(formatRecordDate(''), '');
      expect(formatRecordDate(null), '');
    });
  });

  group('formatDuration 时长展示', () {
    test('小时 + 分钟组合', () {
      expect(formatDuration(85), '1h 25m');
      expect(formatDuration('85'), '1h 25m');
    });

    test('整小时 / 不足一小时', () {
      expect(formatDuration(60), '1h');
      expect(formatDuration(45), '45m');
    });

    test('null / 0 / 非法返回空串（视为未记录）', () {
      expect(formatDuration(null), '');
      expect(formatDuration(0), '');
      expect(formatDuration('abc'), '');
      expect(formatDuration(-10), '');
    });
  });

  group('calcCostPerKwh 度电成本', () {
    test('正常计算并保留两位小数', () {
      // Arrange：¥68 / 45 kWh ≈ 1.5111 → 1.51
      final result = calcCostPerKwh(68, 45);
      expect(result, 1.51);
    });

    test('接受字符串输入', () {
      expect(calcCostPerKwh('15.5', '31'), 0.5);
    });

    test('电量无效（0/负/NaN）返回 null', () {
      expect(calcCostPerKwh(68, 0), isNull);
      expect(calcCostPerKwh(68, -1), isNull);
      expect(calcCostPerKwh(68, 'abc'), isNull);
    });
  });

  group('sortRecordsDesc 记录排序', () {
    test('按日期降序，同日按 createdAt 降序', () {
      // Arrange
      final records = [
        recordOf(id: 'a', date: '2026-08-01', createdAt: 100),
        recordOf(id: 'b', date: '2026-08-23', createdAt: 300),
        recordOf(id: 'c', date: '2026-08-23', createdAt: 200),
        recordOf(id: 'd', date: '2026-07-15', createdAt: 400),
      ];

      // Act
      final result = sortRecordsDesc(records);

      // Assert
      expect(result.map((r) => r.id).toList(), ['b', 'c', 'a', 'd']);
    });

    test('不修改原数组（纯函数），非数组输入返回空数组', () {
      // Arrange
      final records = [
        recordOf(id: 'a', date: '2026-08-01', createdAt: 100),
        recordOf(id: 'b', date: '2026-08-23', createdAt: 300),
      ];

      // Act
      sortRecordsDesc(records);

      // Assert
      expect(records.map((r) => r.id).toList(), ['a', 'b']);
      expect(sortRecordsDesc(null), isEmpty);
    });
  });

  group('calcMonthSummary 月度汇总', () {
    test('只统计目标月的有效记录', () {
      // Arrange：8 月两条有效 + 一条 7 月 + 一条脏数据
      final records = [
        recordOf(date: '2026-08-01', cost: 68, energy: 45),
        recordOf(date: '2026-08-23', cost: 15.5, energy: 31),
        recordOf(date: '2026-07-15', cost: 100, energy: 50),
        recordOf(date: '2026-08-20', cost: 0, energy: 10), // 费用非法，剔除
      ];

      // Act
      final result = calcMonthSummary(records, '2026-08');

      // Assert：总费用 83.5、总电量 76、度电成本 83.5/76 ≈ 1.10
      expect(result.count, 2);
      expect(result.totalCost, 83.5);
      expect(result.totalEnergy, 76);
      expect(result.costPerKwh, 1.1);
    });

    test('空记录 / null 入参返回全零汇总', () {
      final fromEmpty = calcMonthSummary([], '2026-08');
      final fromNull = calcMonthSummary(null, '2026-08');

      expect(fromEmpty.monthKey, '2026-08');
      expect(fromEmpty.count, 0);
      expect(fromEmpty.totalCost, 0);
      expect(fromEmpty.totalEnergy, 0);
      expect(fromEmpty.costPerKwh, isNull);
      expect(fromNull.count, 0);
    });

    test('字符串数值同样计入，汇总金额按分安全取整', () {
      // Arrange：0.1 + 0.2 浮点精度
      final records = [
        recordOf(date: '2026-08-01', cost: 0.1, energy: 1),
        recordOf(date: '2026-08-02', cost: 0.2, energy: 1),
      ];

      // Act
      final result = calcMonthSummary(records, '2026-08');

      // Assert
      expect(result.totalCost, 0.3);
      expect(result.costPerKwh, 0.15);
    });

    test('非法 monthKey 返回 monthKey 为 null 的空汇总', () {
      final result = calcMonthSummary([
        recordOf(date: '2026-08-01', cost: 1, energy: 1),
      ], null);

      expect(result.monthKey, isNull);
      expect(result.count, 0);
      expect(result.totalCost, 0);
      expect(result.totalEnergy, 0);
      expect(result.costPerKwh, isNull);
    });
  });

  group('calcTotalSummary 累计汇总', () {
    test('跨月全量聚合，不按月过滤', () {
      // Arrange：两个月共三条有效 + 一条脏数据
      final records = [
        recordOf(date: '2026-08-01', cost: 68, energy: 45),
        recordOf(date: '2026-07-15', cost: 15.5, energy: 31),
        recordOf(date: '2025-12-30', cost: 42, energy: 28),
        recordOf(date: '2026-08-20', cost: -1, energy: 10), // 费用非法，剔除
      ];

      // Act
      final result = calcTotalSummary(records);

      // Assert：总费用 125.5、总电量 104、度电成本 ≈ 1.21
      expect(result.count, 3);
      expect(result.totalCost, 125.5);
      expect(result.totalEnergy, 104);
      expect(result.costPerKwh, 1.21);
    });

    test('空数组 / null 入参返回全零', () {
      final fromEmpty = calcTotalSummary([]);
      final fromNull = calcTotalSummary(null);

      expect(fromEmpty.count, 0);
      expect(fromEmpty.totalCost, 0);
      expect(fromEmpty.totalEnergy, 0);
      expect(fromEmpty.costPerKwh, isNull);
      expect(fromNull.count, 0);
      expect(fromNull.totalCost, 0);
      expect(fromNull.totalEnergy, 0);
      expect(fromNull.costPerKwh, isNull);
    });

    test('金额分安全取整', () {
      // Arrange：0.1 + 0.2 浮点精度
      final records = [
        recordOf(date: '2026-08-01', cost: 0.1, energy: 1),
        recordOf(date: '2026-07-01', cost: 0.2, energy: 1),
      ];

      expect(calcTotalSummary(records).totalCost, 0.3);
    });
  });

  group('buildRecordFromForm 表单转记录', () {
    test('合法全量输入（字符串）生成规范记录', () {
      // Arrange
      const form = ChargeRecordForm(
        type: 'fast',
        date: '2026-08-23',
        cost: '68',
        energy: '45',
        hours: '1',
        minutes: '25',
        note: '  国家电网快充  ',
      );

      // Act
      final record = buildRecordFromForm(form, now: 1750000000000);

      // Assert
      expect(record?.type, 'fast');
      expect(record?.date, '2026-08-23');
      expect(record?.cost, 68);
      expect(record?.energy, 45);
      expect(record?.durationMinutes, 85);
      expect(record?.note, '国家电网快充');
      expect(record?.createdAt, 1750000000000);
      expect(record?.id, isA<String>());
      expect(record?.id.isNotEmpty, isTrue);
    });

    test('时长留空时 durationMinutes 为 null', () {
      const form = ChargeRecordForm(
        type: 'home',
        date: '2026-08-23',
        cost: 15.5,
        energy: 31,
        hours: '',
        minutes: '',
        note: '',
      );

      expect(buildRecordFromForm(form)?.durationMinutes, isNull);
    });

    test('时长合计为 0 视为未填，返回 null 的 durationMinutes', () {
      const form = ChargeRecordForm(
        type: 'home',
        date: '2026-08-23',
        cost: 15.5,
        energy: 31,
        hours: '0',
        minutes: '0',
        note: '',
      );

      expect(buildRecordFromForm(form)?.durationMinutes, isNull);
    });

    test('分钟超过 59 返回 null', () {
      const form = ChargeRecordForm(
        type: 'home',
        date: '2026-08-23',
        cost: 15.5,
        energy: 31,
        hours: '0',
        minutes: '70',
        note: '',
      );

      expect(buildRecordFromForm(form), isNull);
    });

    test('小时为小数（非整数分钟粒度）返回 null', () {
      const form = ChargeRecordForm(
        type: 'home',
        date: '2026-08-23',
        cost: 15.5,
        energy: 31,
        hours: '1.5',
        minutes: '',
        note: '',
      );

      expect(buildRecordFromForm(form), isNull);
    });

    test('非法输入（缺费用）返回 null', () {
      expect(
        buildRecordFromForm(
          const ChargeRecordForm(
            type: 'fast',
            date: '2026-08-23',
            cost: '',
            energy: 45,
          ),
        ),
        isNull,
      );
    });

    test('非法输入（费用为 0）返回 null', () {
      expect(
        buildRecordFromForm(
          const ChargeRecordForm(
            type: 'fast',
            date: '2026-08-23',
            cost: 0,
            energy: 45,
          ),
        ),
        isNull,
      );
    });

    test('非法输入（费用为负）返回 null', () {
      expect(
        buildRecordFromForm(
          const ChargeRecordForm(
            type: 'fast',
            date: '2026-08-23',
            cost: -1,
            energy: 45,
          ),
        ),
        isNull,
      );
    });

    test('非法输入（缺电量）返回 null', () {
      expect(
        buildRecordFromForm(
          const ChargeRecordForm(
            type: 'fast',
            date: '2026-08-23',
            cost: 68,
            energy: '',
          ),
        ),
        isNull,
      );
    });

    test('非法输入（类型非法）返回 null', () {
      expect(
        buildRecordFromForm(
          const ChargeRecordForm(
            type: 'other',
            date: '2026-08-23',
            cost: 68,
            energy: 45,
          ),
        ),
        isNull,
      );
    });

    test('非法输入（日期格式错）返回 null', () {
      expect(
        buildRecordFromForm(
          const ChargeRecordForm(
            type: 'fast',
            date: '2026/08/23',
            cost: 68,
            energy: 45,
          ),
        ),
        isNull,
      );
    });

    test('非法输入（日期历法错）返回 null', () {
      expect(
        buildRecordFromForm(
          const ChargeRecordForm(
            type: 'fast',
            date: '2024-13-01',
            cost: 68,
            energy: 45,
          ),
        ),
        isNull,
      );
    });

    test('note 超长时截断到 100 字', () {
      final form = ChargeRecordForm(
        type: 'fast',
        date: '2026-08-23',
        cost: 68,
        energy: 45,
        note: '长' * 120,
      );

      final record = buildRecordFromForm(form);

      expect(record?.note.length, 100);
    });
  });

  group('normalizeStoredRecord 存储记录守卫', () {
    test('合法记录原样通过（字段白名单拷贝，无车辆/地点字段补 null）', () {
      final record = normalizeStoredRecord(baseRaw({'extraField': 'hack'}));

      expect(record?.id, 'r1');
      expect(record?.type, 'fast');
      expect(record?.date, '2026-08-23');
      expect(record?.cost, 68);
      expect(record?.energy, 45);
      expect(record?.durationMinutes, 85);
      expect(record?.note, 'x');
      expect(record?.createdAt, 1000);
      expect(record?.vehicleId, isNull);
      expect(record?.vehicleName, isNull);
      expect(record?.province, isNull);
      expect(record?.city, isNull);
      expect(record?.locationName, isNull);
      expect(record?.latitude, isNull);
      expect(record?.longitude, isNull);
    });

    test('durationMinutes 缺失或非法时归一为 null', () {
      final raw = baseRaw()..remove('durationMinutes');
      expect(normalizeStoredRecord(raw)?.durationMinutes, isNull);
      expect(
        normalizeStoredRecord(
          baseRaw({'durationMinutes': -5}),
        )?.durationMinutes,
        isNull,
      );
    });

    test('非法记录（非对象）返回 null', () {
      expect(normalizeStoredRecord(null), isNull);
    });

    test('非法记录（缺 id）返回 null', () {
      expect(normalizeStoredRecord(baseRaw({'id': ''})), isNull);
    });

    test('非法记录（类型非法）返回 null', () {
      expect(normalizeStoredRecord(baseRaw({'type': 'other'})), isNull);
    });

    test('非法记录（日期非法）返回 null', () {
      expect(normalizeStoredRecord(baseRaw({'date': 'abc'})), isNull);
    });

    test('非法记录（费用非法）返回 null', () {
      expect(normalizeStoredRecord(baseRaw({'cost': 0})), isNull);
    });

    test('非法记录（电量非法）返回 null', () {
      expect(normalizeStoredRecord(baseRaw({'energy': 'abc'})), isNull);
    });
  });

  group('TYPE_DEFAULT_TITLES', () {
    test('包含快充 / 家充默认标题', () {
      expect(typeDefaultTitles['fast'], 'Fast (DC)');
      expect(typeDefaultTitles['home'], 'Home (AC)');
    });
  });

  group('formatTimestampDate 时间戳转日期', () {
    test('合法时间戳 → YYYY-MM-DD', () {
      expect(
        formatTimestampDate(DateTime(2025, 8, 1).millisecondsSinceEpoch),
        '2025-08-01',
      );
    });

    test('非法输入返回空串', () {
      expect(formatTimestampDate('abc'), '');
      expect(formatTimestampDate(0), '');
      expect(formatTimestampDate(null), '');
    });
  });

  group('充电时长上限与车辆字段', () {
    test('时长 72 小时合法', () {
      const form = ChargeRecordForm(
        type: 'home',
        date: '2026-08-23',
        cost: 100,
        energy: 100,
        hours: '72',
        minutes: '0',
        note: '',
      );
      expect(buildRecordFromForm(form)?.durationMinutes, 4320);
    });

    test('时长 73 小时返回 null', () {
      const form = ChargeRecordForm(
        type: 'home',
        date: '2026-08-23',
        cost: 100,
        energy: 100,
        hours: '73',
        minutes: '0',
        note: '',
      );
      expect(buildRecordFromForm(form), isNull);
    });

    test('带车辆字段的表单产出 vehicleId / vehicleName 快照', () {
      const form = ChargeRecordForm(
        type: 'fast',
        date: '2026-08-23',
        cost: 30,
        energy: 40,
        hours: '1',
        minutes: '0',
        note: '',
        vehicleId: 'v-1',
        vehicleName: '  我的小电  ',
      );
      final record = buildRecordFromForm(form);
      expect(record?.vehicleId, 'v-1');
      expect(record?.vehicleName, '我的小电');
    });

    test('无车辆字段时产出 null（向后兼容旧表单）', () {
      const form = ChargeRecordForm(
        type: 'fast',
        date: '2026-08-23',
        cost: 30,
        energy: 40,
        note: '',
      );
      final record = buildRecordFromForm(form);
      expect(record?.vehicleId, isNull);
      expect(record?.vehicleName, isNull);
    });

    test('normalizeStoredRecord 对旧记录（无车辆字段）产出 null', () {
      final record = normalizeStoredRecord(<String, dynamic>{
        'id': 'r1',
        'type': 'fast',
        'date': '2026-08-01',
        'cost': 30,
        'energy': 40,
        'durationMinutes': 60,
        'createdAt': 1754000000000,
      });
      expect(record?.vehicleId, isNull);
      expect(record?.vehicleName, isNull);
    });

    test('normalizeStoredRecord 透传车辆字段并剔除非法类型', () {
      final base = <String, dynamic>{
        'id': 'r1',
        'type': 'fast',
        'date': '2026-08-01',
        'cost': 30,
        'energy': 40,
        'createdAt': 1,
      };
      expect(
        normalizeStoredRecord({
          ...base,
          'vehicleId': 'v-1',
          'vehicleName': '我的小电',
        })?.vehicleName,
        '我的小电',
      );
      expect(
        normalizeStoredRecord({
          ...base,
          'vehicleId': 123,
          'vehicleName': 456,
        })?.vehicleId,
        isNull,
      );
    });
  });

  group('地点字段（省市/地点名/经纬度）', () {
    ChargeRecordForm baseForm() {
      return const ChargeRecordForm(
        type: 'home',
        date: '2026-08-23',
        cost: 15.5,
        energy: 31,
        note: '',
      );
    }

    Map<String, dynamic> baseRawMap() {
      return <String, dynamic>{
        'id': 'r1',
        'type': 'home',
        'date': '2026-08-23',
        'cost': 15.5,
        'energy': 31,
        'createdAt': 1000,
      };
    }

    test('buildRecordFromForm 接受合法地点字段（字符串坐标）', () {
      final record = buildRecordFromForm(
        ChargeRecordForm.fromMap({
          ...baseForm().toMap(),
          'province': ' 浙江省 ',
          'city': '杭州市',
          'locationName': '  家充  ',
          'latitude': '30.2741',
          'longitude': '120.1551',
        }),
      );

      expect(record?.province, '浙江省');
      expect(record?.city, '杭州市');
      expect(record?.locationName, '家充');
      expect(record?.latitude, closeTo(30.2741, 1e-9));
      expect(record?.longitude, closeTo(120.1551, 1e-9));
    });

    test('无地点字段时全部产出 null（向后兼容）', () {
      final record = buildRecordFromForm(baseForm());

      expect(record?.province, isNull);
      expect(record?.city, isNull);
      expect(record?.locationName, isNull);
      expect(record?.latitude, isNull);
      expect(record?.longitude, isNull);
    });

    test('经纬度只填一个合法值时两个都丢弃', () {
      final onlyLat = buildRecordFromForm(
        const ChargeRecordForm(
          type: 'home',
          date: '2026-08-23',
          cost: 15.5,
          energy: 31,
          note: '',
          latitude: 30.27,
          longitude: 'abc',
        ),
      );
      final outOfRange = buildRecordFromForm(
        const ChargeRecordForm(
          type: 'home',
          date: '2026-08-23',
          cost: 15.5,
          energy: 31,
          note: '',
          latitude: 80,
          longitude: 120,
        ),
      );

      expect(onlyLat?.latitude, isNull);
      expect(onlyLat?.longitude, isNull);
      expect(outOfRange?.latitude, isNull);
      expect(outOfRange?.longitude, isNull);
    });

    test('地点字段不影响核心校验（无地点的表单仍可保存）', () {
      expect(buildRecordFromForm(baseForm()), isNotNull);
      expect(
        buildRecordFromForm(
          const ChargeRecordForm(
            type: 'home',
            date: '2026-08-23',
            cost: 15.5,
            energy: 31,
            note: '',
            city: 123,
            latitude: 'x',
          ),
        ),
        isNotNull,
      );
    });

    test('locationName 超长截断到 30 字', () {
      final record = buildRecordFromForm(
        ChargeRecordForm(
          type: 'home',
          date: '2026-08-23',
          cost: 15.5,
          energy: 31,
          note: '',
          locationName: '长' * 40,
        ),
      );

      expect(record?.locationName?.length, 30);
    });

    test('normalizeStoredRecord 白名单透传地点字段并守卫非法值', () {
      final valid = normalizeStoredRecord({
        ...baseRawMap(),
        'province': '浙江省',
        'city': '杭州市',
        'locationName': '家充',
        'latitude': 30.2741,
        'longitude': 120.1551,
      });
      final invalid = normalizeStoredRecord({
        ...baseRawMap(),
        'province': 1,
        'locationName': '  ',
        'latitude': 999,
      });

      expect(valid?.province, '浙江省');
      expect(valid?.latitude, closeTo(30.2741, 1e-9));
      expect(invalid?.province, isNull);
      expect(invalid?.locationName, isNull);
      expect(invalid?.latitude, isNull);
      expect(invalid?.longitude, isNull);
    });
  });

  group('applyVehicleRename / applyVehicleRemoval 车辆同步', () {
    List<ChargeRecord> vehicleRecords() {
      return [
        recordOf(id: 'r1', vehicleId: 'v1', vehicleName: '旧名'),
        recordOf(id: 'r2', vehicleId: 'v2', vehicleName: '别辆车'),
        recordOf(id: 'r3'),
      ];
    }

    test('改名只更新 id 匹配的记录，且不改原数组', () {
      final records = vehicleRecords();
      final next = applyVehicleRename(records, 'v1', '  新车名  ');
      expect(next[0].vehicleName, '新车名');
      expect(next[1].vehicleName, '别辆车');
      expect(records[0].vehicleName, '旧名'); // 原数组不动
    });

    test('改名对超长名称截断', () {
      final next = applyVehicleRename(vehicleRecords(), 'v1', 'a' * 30);
      expect(next[0].vehicleName?.length, 20); // vehicleNameMaxLength
    });

    test('vehicleId 非法时原样返回新数组', () {
      expect(
        applyVehicleRename(vehicleRecords(), '', 'x')[0].vehicleName,
        '旧名',
      );
      expect(applyVehicleRename(null, 'v1', 'x'), isEmpty);
    });

    test('删除清除关联记录的车辆字段', () {
      final records = vehicleRecords();
      final next = applyVehicleRemoval(records, 'v1');
      expect(next[0].vehicleId, isNull);
      expect(next[0].vehicleName, isNull);
      expect(next[1].vehicleId, 'v2'); // 其他车不受影响
      expect(records[0].vehicleId, 'v1');
    });

    test('applyVehicleSnapshotRename / applyVehicleSnapshotRemoval 同口径', () {
      final renamed = applyVehicleSnapshotRename(
        vehicleRecords(),
        'v1',
        '  新车名  ',
      );
      expect(renamed[0].vehicleName, '新车名');
      final removed = applyVehicleSnapshotRemoval(vehicleRecords(), 'v1');
      expect(removed[0].vehicleId, isNull);
      expect(removed[0].vehicleName, isNull);
    });
  });

  group('getAvailableMonths 有记录月份列表', () {
    test('返回降序去重的月份 key，忽略非法日期记录', () {
      final records = [
        recordOf(
          id: 'r1',
          type: 'fast',
          date: '2026-08-15',
          cost: 30,
          energy: 40,
        ),
        recordOf(
          id: 'r2',
          type: 'home',
          date: '2026-08-02',
          cost: 10,
          energy: 15,
        ),
        recordOf(
          id: 'r3',
          type: 'fast',
          date: '2025-12-31',
          cost: 25,
          energy: 35,
        ),
        recordOf(
          id: 'r4',
          type: 'home',
          date: '2026-01-01',
          cost: 12,
          energy: 18,
        ),
        recordOf(id: 'r5', type: 'fast', date: '非法日期', cost: 1, energy: 2),
      ];

      expect(getAvailableMonths(records), ['2026-08', '2026-01', '2025-12']);
    });

    test('空数组 / 非数组输入返回空数组', () {
      expect(getAvailableMonths([]), isEmpty);
      expect(getAvailableMonths(null), isEmpty);
    });
  });

  group('shiftMonthKey 月份平移', () {
    test('年内平移', () {
      expect(shiftMonthKey('2026-08', -1), '2026-07');
      expect(shiftMonthKey('2026-08', 1), '2026-09');
    });

    test('跨年平移（正负两个方向）', () {
      expect(shiftMonthKey('2026-01', -1), '2025-12');
      expect(shiftMonthKey('2025-12', 1), '2026-01');
    });

    test('delta 为 0 原样返回', () {
      expect(shiftMonthKey('2026-08', 0), '2026-08');
    });

    test('非法 monthKey / 非整数 delta 返回 null', () {
      expect(shiftMonthKey('2026-8', 1), isNull);
      expect(shiftMonthKey('', 1), isNull);
      expect(shiftMonthKey(null, 1), isNull);
      expect(shiftMonthKey('2026-08', 1.5), isNull);
      expect(shiftMonthKey('2026-08', double.nan), isNull);
    });
  });

  group('formatMonthLabel 月份文案', () {
    test('补零月与不补零月均输出英文月份缩写', () {
      expect(formatMonthLabel('2026-08'), 'Aug 2026');
      expect(formatMonthLabel('2026-11'), 'Nov 2026');
    });

    test('非法输入返回空串', () {
      expect(formatMonthLabel('2026-8'), '');
      expect(formatMonthLabel(null), '');
    });
  });

  group('filterRecords 组合筛选', () {
    List<ChargeRecord> filterSource() {
      return [
        recordOf(id: 'r1', type: 'fast', date: '2026-08-01', vehicleId: 'v1'),
        recordOf(id: 'r2', type: 'home', date: '2026-08-15', vehicleId: 'v2'),
        recordOf(id: 'r3', type: 'fast', date: '2026-07-20', vehicleId: 'v1'),
        recordOf(id: 'r4', type: 'home', date: '2025-12-31'),
      ];
    }

    test('按月份筛选', () {
      final result = filterRecords(
        filterSource(),
        const RecordFilters(monthKey: '2026-08'),
      );
      expect(result.map((r) => r.id).toList(), ['r1', 'r2']);
    });

    test('按年份筛选', () {
      expect(
        filterRecords(
          filterSource(),
          const RecordFilters(year: '2026'),
        ).map((r) => r.id).toList(),
        ['r1', 'r2', 'r3'],
      );
      expect(
        filterRecords(
          filterSource(),
          const RecordFilters(year: '2025'),
        ).map((r) => r.id).toList(),
        ['r4'],
      );
    });

    test('按类型筛选', () {
      expect(
        filterRecords(
          filterSource(),
          const RecordFilters(type: 'fast'),
        ).map((r) => r.id).toList(),
        ['r1', 'r3'],
      );
    });

    test('按车辆筛选', () {
      expect(
        filterRecords(
          filterSource(),
          const RecordFilters(vehicleId: 'v2'),
        ).map((r) => r.id).toList(),
        ['r2'],
      );
    });

    test('组合条件取交集', () {
      final result = filterRecords(
        filterSource(),
        const RecordFilters(monthKey: '2026-08', type: 'fast'),
      );
      expect(result.map((r) => r.id).toList(), ['r1']);
    });

    test('条件全为 null 时全量返回（新数组，不改原数组）', () {
      final records = filterSource();
      final all = filterRecords(records, const RecordFilters());
      expect(all.map((r) => r.id).toList(), ['r1', 'r2', 'r3', 'r4']);
      expect(identical(all, records), isFalse); // 返回新数组
    });

    test('非法 type 值（非 fast/home）返回空数组', () {
      expect(
        filterRecords(filterSource(), const RecordFilters(type: 'other')),
        isEmpty,
      );
    });

    test('非数组输入返回空数组', () {
      expect(
        filterRecords(null, const RecordFilters(monthKey: '2026-08')),
        isEmpty,
      );
    });
  });

  group('buildMonthSummaryText 月度小结文案', () {
    test('有记录时输出次数/花费/度电均价', () {
      // Arrange
      const summary = MonthSummary(
        monthKey: '2026-09',
        count: 12,
        totalCost: 320.5,
        totalEnergy: 445.2,
        costPerKwh: 0.72,
      );

      // Act
      final text = buildMonthSummaryText(summary, 'Sep 2026');

      // Assert
      expect(text, 'Sep 2026 · 12 charges · \$320.50 total · avg \$0.72/kWh');
    });

    test('costPerKwh 为 null（无有效电量）时均价降级为 --', () {
      const summary = MonthSummary(
        monthKey: '2026-09',
        count: 3,
        totalCost: 90,
        totalEnergy: 0,
        costPerKwh: null,
      );

      expect(
        buildMonthSummaryText(summary, 'Sep 2026'),
        'Sep 2026 · 3 charges · \$90.00 total · avg \$--/kWh',
      );
    });

    test('无记录时输出占位文案', () {
      const empty = MonthSummary(
        monthKey: '2026-09',
        count: 0,
        totalCost: 0,
        totalEnergy: 0,
        costPerKwh: null,
      );
      expect(
        buildMonthSummaryText(empty, 'Sep 2026'),
        'Sep 2026 · No charging records yet',
      );
      expect(
        buildMonthSummaryText(null, 'Sep 2026'),
        'Sep 2026 · No charging records yet',
      );
    });
  });

  group('ChargeRecord 序列化', () {
    test('toJson / fromJson 往返保留字段', () {
      const record = ChargeRecord(
        id: 'r1',
        type: 'fast',
        date: '2026-08-23',
        cost: 68.5,
        energy: 45.25,
        durationMinutes: 85,
        note: 'x',
        vehicleId: 'v1',
        vehicleName: '我的小电',
        province: '浙江省',
        city: '杭州市',
        locationName: '家充',
        latitude: 30.2741,
        longitude: 120.1551,
        createdAt: 1000,
      );

      final json = record.toJson();
      expect(json.keys.toList(), [
        'id',
        'type',
        'date',
        'cost',
        'energy',
        'durationMinutes',
        'note',
        'vehicleId',
        'vehicleName',
        'province',
        'city',
        'locationName',
        'latitude',
        'longitude',
        'createdAt',
      ]);
      final restored = ChargeRecord.fromJson(json);
      expect(restored.id, record.id);
      expect(restored.type, record.type);
      expect(restored.date, record.date);
      expect(restored.cost, record.cost);
      expect(restored.energy, record.energy);
      expect(restored.durationMinutes, record.durationMinutes);
      expect(restored.note, record.note);
      expect(restored.vehicleId, record.vehicleId);
      expect(restored.vehicleName, record.vehicleName);
      expect(restored.province, record.province);
      expect(restored.city, record.city);
      expect(restored.locationName, record.locationName);
      expect(restored.latitude, record.latitude);
      expect(restored.longitude, record.longitude);
      expect(restored.createdAt, record.createdAt);
    });

    test('toJson 整数金额序列化为 int（与 JS 存储形态一致）', () {
      const record = ChargeRecord(cost: 68, energy: 45, createdAt: 1);
      expect(record.toJson()['cost'], 68);
      expect(record.toJson()['energy'], 45);
    });

    test('copyWith 局部覆盖', () {
      const record = ChargeRecord(id: 'r1', vehicleName: '旧名');
      final next = record.copyWith(vehicleName: '新名');
      expect(next.id, 'r1');
      expect(next.vehicleName, '新名');
    });
  });
}
