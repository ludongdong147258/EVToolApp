/// vehicles.dart 单测（移植自 src/lib/__tests__/vehicles.test.js；
/// 快照同步用例见 maintenance_costs_test.dart）
library;

import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造仅含排序所需字段的最小车辆
Vehicle vehicleOf({
  required String id,
  bool isDefault = false,
  int createdAt = 0,
}) {
  return Vehicle(
    id: id,
    name: '小白',
    battery: 60,
    note: '',
    photoPath: '',
    isDefault: isDefault,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  group('normalizeVehicleName 车辆昵称规整', () {
    test('去除首尾空白后返回字符串', () {
      expect(normalizeVehicleName('  小白 '), '小白');
    });

    test('超过最大长度时截断', () {
      final raw = 'a' * (vehicleNameMaxLength + 1);
      expect(normalizeVehicleName(raw), 'a' * vehicleNameMaxLength);
    });

    test('空白或非字符串输入返回 null', () {
      expect(normalizeVehicleName('   '), isNull);
      expect(normalizeVehicleName(''), isNull);
      expect(normalizeVehicleName(null), isNull);
      expect(normalizeVehicleName(123), isNull);
    });
  });

  group('parseBattery 电池容量解析', () {
    test('接受字符串与数字，四舍五入到一位小数', () {
      expect(parseBattery('60'), 60);
      expect(parseBattery(23.68), 23.7);
      expect(parseBattery('75.5'), 75.5);
    });

    test('边界值 15 与 200 合法', () {
      expect(parseBattery(batteryMin), batteryMin);
      expect(parseBattery(batteryMax), batteryMax);
    });

    test('越界或非法输入返回 null', () {
      expect(parseBattery(batteryMin - 0.1), isNull);
      expect(parseBattery(batteryMax + 0.1), isNull);
      expect(parseBattery(0), isNull);
      expect(parseBattery(-60), isNull);
      expect(parseBattery('abc'), isNull);
      expect(parseBattery(null), isNull);
    });
  });

  group('normalizePhotoPath 车辆照片路径规整', () {
    test('合法路径 trim 后保留', () {
      expect(
        normalizePhotoPath(' wxfile://store/1.png '),
        'wxfile://store/1.png',
      );
    });

    test('空白或非字符串输入返回空字符串', () {
      expect(normalizePhotoPath('   '), '');
      expect(normalizePhotoPath(''), '');
      expect(normalizePhotoPath(null), '');
      expect(normalizePhotoPath(123), '');
    });

    test('超过最大长度时截断', () {
      final raw = 'a' * (photoPathMaxLength + 10);
      expect(normalizePhotoPath(raw), 'a' * photoPathMaxLength);
    });
  });

  group('buildVehicleFromForm 表单 → 规范车辆', () {
    test('合法输入返回含全部字段的规范车辆', () {
      // Arrange
      const form = VehicleForm(
        name: ' 小白 ',
        battery: '60.44',
        note: ' 家充为主 ',
        photoPath: 'wxfile://photo',
      );

      // Act
      final vehicle = buildVehicleFromForm(
        form,
        1700000000000,
        isDefault: true,
      );

      // Assert
      expect(vehicle, isNotNull);
      final v = vehicle;
      if (v == null) {
        fail('合法输入应生成规范车辆');
      }
      expect(v.id, isA<String>());
      expect(v.name, '小白');
      expect(v.battery, 60.4);
      expect(v.note, '家充为主');
      expect(v.photoPath, 'wxfile://photo');
      expect(v.isDefault, true);
      expect(v.createdAt, 1700000000000);
      expect(v.updatedAt, 1700000000000);
    });

    test('photoPath 缺省或非法为空字符串，不影响整车构建', () {
      final withoutPhoto = buildVehicleFromForm(
        const VehicleForm(name: '小白', battery: 60),
        1,
      );
      final withBadPhoto = buildVehicleFromForm(
        const VehicleForm(name: '小白', battery: 60, photoPath: 99),
        1,
      );

      expect(withoutPhoto?.photoPath, '');
      expect(withBadPhoto?.photoPath, '');
      expect(withBadPhoto, isNotNull);
    });

    test('昵称为空或容量越界返回 null', () {
      expect(
        buildVehicleFromForm(const VehicleForm(name: '   ', battery: '60'), 1),
        isNull,
      );
      expect(
        buildVehicleFromForm(const VehicleForm(name: '小白', battery: '201'), 1),
        isNull,
      );
    });

    test('备注超长截断，未填备注为空字符串', () {
      final withLongNote = buildVehicleFromForm(
        VehicleForm(
          name: '小白',
          battery: 60,
          note: 'a' * (vehicleNoteMaxLength + 10),
        ),
        1,
      );
      final withoutNote = buildVehicleFromForm(
        const VehicleForm(name: '小白', battery: 60),
        1,
      );

      expect(withLongNote?.note, 'a' * vehicleNoteMaxLength);
      expect(withoutNote?.note, '');
    });
  });

  group('normalizeStoredVehicle 存储守卫', () {
    test('合法对象按白名单拷贝并丢弃未知字段', () {
      // Arrange
      final raw = <String, dynamic>{
        'id': 123,
        'name': '小白',
        'battery': 60,
        'note': '备注',
        'photoPath': 'wxfile://photo',
        'isDefault': true,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000001,
        'extra': 'hack',
      };

      // Act
      final vehicle = normalizeStoredVehicle(raw);
      if (vehicle == null) {
        fail('合法存储数据应通过守卫');
      }

      // Assert
      expect(vehicle.id, '123');
      expect(vehicle.name, '小白');
      expect(vehicle.battery, 60);
      expect(vehicle.note, '备注');
      expect(vehicle.photoPath, 'wxfile://photo');
      expect(vehicle.isDefault, true);
      expect(vehicle.createdAt, 1700000000000);
      expect(vehicle.updatedAt, 1700000000001);
      expect(vehicle.toJson().containsKey('extra'), isFalse);
    });

    test('photoPath 缺失或非法归一为空字符串', () {
      final withoutPhoto = normalizeStoredVehicle(<String, dynamic>{
        'id': 'a',
        'name': '小白',
        'battery': 60,
      });
      final withBadPhoto = normalizeStoredVehicle(<String, dynamic>{
        'id': 'b',
        'name': '小白',
        'battery': 60,
        'photoPath': ' ',
      });

      expect(withoutPhoto?.photoPath, '');
      expect(withBadPhoto?.photoPath, '');
    });

    test('缺 id、昵称非法或容量越界返回 null', () {
      expect(normalizeStoredVehicle(null), isNull);
      expect(
        normalizeStoredVehicle(<String, dynamic>{'name': '小白', 'battery': 60}),
        isNull,
      );
      expect(
        normalizeStoredVehicle(<String, dynamic>{
          'id': 'a',
          'name': '  ',
          'battery': 60,
        }),
        isNull,
      );
      expect(
        normalizeStoredVehicle(<String, dynamic>{
          'id': 'a',
          'name': '小白',
          'battery': 10,
        }),
        isNull,
      );
    });

    test('note/createdAt 缺失或非法时容错', () {
      // Arrange
      final raw = <String, dynamic>{
        'id': 'a',
        'name': '小白',
        'battery': 60,
        'createdAt': 'bad',
      };

      // Act
      final vehicle = normalizeStoredVehicle(raw);
      if (vehicle == null) {
        fail('合法存储数据应通过守卫');
      }

      // Assert
      expect(vehicle.note, '');
      expect(vehicle.createdAt, 0);
      expect(vehicle.updatedAt, 0);
    });
  });

  group('sortVehicles 车辆排序', () {
    test('默认车置顶，其余按 createdAt 降序', () {
      // Arrange
      final vehicles = <Vehicle>[
        vehicleOf(id: 'a', isDefault: false, createdAt: 100),
        vehicleOf(id: 'b', isDefault: false, createdAt: 300),
        vehicleOf(id: 'c', isDefault: true, createdAt: 50),
      ];

      // Act
      final sorted = sortVehicles(vehicles);

      // Assert
      expect(sorted.map((item) => item.id).toList(), <String>['c', 'b', 'a']);
    });

    test('返回新数组且非数组输入返回空数组', () {
      final vehicles = <Vehicle>[vehicleOf(id: 'a', createdAt: 1)];

      expect(identical(sortVehicles(vehicles), vehicles), isFalse);
      expect(vehicles.map((item) => item.id).toList(), <String>['a']);
      expect(sortVehicles(null), isEmpty);
    });
  });

  group('ensureSingleDefault 默认车不变量', () {
    test('空列表与非数组输入返回空数组', () {
      expect(ensureSingleDefault(<Vehicle>[]), isEmpty);
      expect(ensureSingleDefault(null), isEmpty);
    });

    test('无默认时把排序后首辆置为默认', () {
      final vehicles = <Vehicle>[
        vehicleOf(id: 'a', isDefault: false, createdAt: 100),
        vehicleOf(id: 'b', isDefault: false, createdAt: 300),
      ];

      final result = ensureSingleDefault(vehicles);

      expect(result[0].id, 'b');
      expect(result[0].isDefault, true);
      expect(result[1].isDefault, false);
    });

    test('多辆默认时只保留排序最前的一辆', () {
      final vehicles = <Vehicle>[
        vehicleOf(id: 'a', isDefault: true, createdAt: 100),
        vehicleOf(id: 'b', isDefault: true, createdAt: 300),
        vehicleOf(id: 'c', isDefault: false, createdAt: 200),
      ];

      final result = ensureSingleDefault(vehicles);

      expect(result.where((item) => item.isDefault).length, 1);
      expect(result[0].id, 'b');
    });

    test('返回新数组且不修改入参', () {
      final vehicles = <Vehicle>[
        vehicleOf(id: 'a', isDefault: false, createdAt: 1),
      ];

      final result = ensureSingleDefault(vehicles);

      expect(identical(result, vehicles), isFalse);
      expect(vehicles[0].isDefault, false);
    });
  });

  group('canAddVehicle 免费档车辆上限（Pro 订阅新增，非小程序移植）', () {
    test('非 Pro：低于上限可新增，达到上限不可新增', () {
      expect(canAddVehicle(0, false), isTrue);
      expect(canAddVehicle(1, false), isFalse);
      expect(canAddVehicle(2, false), isFalse);
    });

    test('Pro：数量不限', () {
      expect(canAddVehicle(2, true), isTrue);
      expect(canAddVehicle(9, true), isTrue);
    });
  });
}
