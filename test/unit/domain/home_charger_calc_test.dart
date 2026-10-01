import 'package:ev_tool_app/core/domain/home_charger_calc.dart';
import 'package:flutter_test/flutter_test.dart';

/* 第 2 步默认开启的环境条件（车库 + 保护箱） */
const Map<String, bool> defaultConditions = {
  'undergroundGarage': true,
  'groundSpot': false,
  'wallDrilling': false,
  'protectionBox': true,
};

void main() {
  group('calcInstallEstimate 私桩安装测算', () {
    test('默认输入（30 米 + 7kW）与设计稿一致：总额 2850', () {
      // Arrange
      const inputs = HomeChargerInputs();

      // Act
      final result = calcInstallEstimate(inputs);

      // Assert
      // 30 米未超基础包含长度，无超长费用；未传 conditions 无环境附加
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.basePrice, 2850);
      expect(result.extraCableLength, 0);
      expect(result.extraCableCost, 0);
      expect(result.surcharges, isEmpty);
      expect(result.surchargeTotal, 0);
      expect(result.total, 2850);
    });

    test('线缆超出 30 米时按单价加收超长费用', () {
      // Arrange：60 米超 30 米 × ¥30 = ¥900
      const inputs = HomeChargerInputs(cableLength: 60, powerId: '7kw');

      // Act
      final result = calcInstallEstimate(inputs);

      // Assert
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.extraCableLength, 30);
      expect(result.extraCableCost, 900);
      expect(result.total, 3750);
    });

    test('线缆不足 30 米不退费', () {
      // Arrange
      const inputs = HomeChargerInputs(cableLength: 10, powerId: '7kw');

      // Act
      final result = calcInstallEstimate(inputs);

      // Assert
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.extraCableLength, 0);
      expect(result.extraCableCost, 0);
      expect(result.total, 2850);
    });

    for (final option in powerOptions) {
      test('${option.id} 使用对应基础包价格', () {
        // Arrange & Act
        final result = calcInstallEstimate(
          HomeChargerInputs(cableLength: 30, powerId: option.id),
        );

        // Assert
        if (result == null) {
          fail('result should not be null');
        }
        expect(result.basePrice, option.basePrice);
        expect(result.total, option.basePrice);
      });
    }

    test('接受字符串形式的线缆长度（来自滑块/输入框）', () {
      // Arrange & Act
      final result = calcInstallEstimate(
        const HomeChargerInputs(cableLength: '45', powerId: '7kw'),
      );

      // Assert：45 − 30 = 15 米 × ¥30 = ¥450
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.extraCableCost, 450);
      expect(result.total, 3300);
    });

    test('线缆长度越界（负数 / 超上限）时返回 null', () {
      // Arrange & Act
      final negativeResult = calcInstallEstimate(
        const HomeChargerInputs(cableLength: -1, powerId: '7kw'),
      );
      final overMaxResult = calcInstallEstimate(
        const HomeChargerInputs(cableLength: cableMax + 1, powerId: '7kw'),
      );

      // Assert
      expect(negativeResult, isNull);
      expect(overMaxResult, isNull);
    });

    test('未知 powerId 或空串线缆长度返回 null', () {
      // Arrange & Act
      final unknownPowerResult = calcInstallEstimate(
        const HomeChargerInputs(cableLength: 30, powerId: '33kw'),
      );
      final emptyResult = calcInstallEstimate(
        const HomeChargerInputs(cableLength: '', powerId: '7kw'),
      );
      final nanResult = calcInstallEstimate(
        const HomeChargerInputs(cableLength: 'abc', powerId: '7kw'),
      );

      // Assert
      expect(unknownPowerResult, isNull);
      expect(emptyResult, isNull);
      expect(nanResult, isNull);
    });

    test('线缆长度边界（0 米与上限 100 米）计算正确', () {
      // Arrange & Act
      final minResult = calcInstallEstimate(
        const HomeChargerInputs(cableLength: cableMin, powerId: '7kw'),
      );
      final maxResult = calcInstallEstimate(
        const HomeChargerInputs(cableLength: cableMax, powerId: '11kw'),
      );

      // Assert：100 − 30 = 70 米 × ¥30 = ¥2100；11kW 基础 3600
      if (minResult == null || maxResult == null) {
        fail('results should not be null');
      }
      expect(minResult.total, 2850);
      expect(maxResult.extraCableLength, 70);
      expect(maxResult.total, 5700);
    });
  });

  group('calcInstallEstimate 环境增项计价', () {
    test('默认条件（车库+保护箱）与设计稿一致：增项 430、总额 3280', () {
      // Arrange
      const inputs = HomeChargerInputs(
        cableLength: 30,
        powerId: '7kw',
        conditions: defaultConditions,
      );

      // Act
      final result = calcInstallEstimate(inputs);

      // Assert
      // 2850 + 200（车库）+ 230（保护箱）= 3280
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.surcharges.length, 2);
      expect(result.surcharges[0].id, 'undergroundGarage');
      expect(result.surcharges[0].price, 200);
      expect(result.surcharges[1].id, 'protectionBox');
      expect(result.surcharges[1].price, 230);
      expect(result.surchargeTotal, 430);
      expect(result.total, 3280);
    });

    test('不传 conditions 时无环境附加，总额同旧口径（向后兼容）', () {
      // Arrange & Act
      final result = calcInstallEstimate(
        const HomeChargerInputs(cableLength: 30, powerId: '7kw'),
      );

      // Assert
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.surcharges, isEmpty);
      expect(result.surchargeTotal, 0);
      expect(result.total, 2850);
    });

    test('全部开关关闭时增项为 0', () {
      // Arrange
      const allOff = {
        'undergroundGarage': false,
        'groundSpot': false,
        'wallDrilling': false,
        'protectionBox': false,
      };

      // Act
      final result = calcInstallEstimate(
        const HomeChargerInputs(
          cableLength: 30,
          powerId: '7kw',
          conditions: allOff,
        ),
      );

      // Assert
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.surcharges, isEmpty);
      expect(result.surchargeTotal, 0);
      expect(result.total, 2850);
    });

    test('穿墙打孔开启加收 150，地面车位不计费', () {
      // Arrange
      const conditions = {
        'undergroundGarage': false,
        'groundSpot': true,
        'wallDrilling': true,
        'protectionBox': false,
      };

      // Act
      final result = calcInstallEstimate(
        const HomeChargerInputs(
          cableLength: 30,
          powerId: '11kw',
          conditions: conditions,
        ),
      );

      // Assert：3600 + 150（穿墙）
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.surcharges.length, 1);
      expect(result.surcharges[0].id, 'wallDrilling');
      expect(result.surcharges[0].price, 150);
      expect(result.total, 3750);
    });

    test('环境增项与超长线缆叠加计算', () {
      // Arrange：60 米超 30 × ¥30 = 900；车库+保护箱 430
      const inputs = HomeChargerInputs(
        cableLength: 60,
        powerId: '7kw',
        conditions: defaultConditions,
      );

      // Act
      final result = calcInstallEstimate(inputs);

      // Assert：2850 + 900 + 430
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.total, 4180);
    });
  });

  group('formatAmount 金额千分位', () {
    test('2850 → "2,850"', () {
      expect(formatAmount(2850), '2,850');
    });

    test('3600 与 12000 → "3,600" / "12,000"', () {
      expect(formatAmount(3600), '3,600');
      expect(formatAmount(12000), '12,000');
    });

    test('小于 1000 不加分隔符', () {
      expect(formatAmount(900), '900');
      expect(formatAmount(0), '0');
    });
  });

  group('normalizeStoredEstimate 存储守卫', () {
    const baseRaw = StoredEstimateInput(
      id: 'e1',
      cableLength: 30,
      powerId: '7kw',
      spot: 'undergroundGarage',
      conditions: {'undergroundGarage': true},
      savedAt: 1754000000000,
    );

    test('合法数据通过并重算 estimate', () {
      final result = normalizeStoredEstimate(baseRaw);
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.id, 'e1');
      expect(result.estimate.total, 3050); // 2850 + 200 车库增项
    });

    test('缺 id 返回 null', () {
      expect(
        normalizeStoredEstimate(
          baseRaw.copyWith(
            id: '',
            cableLength: 30,
            powerId: '7kw',
            savedAt: 1754000000000,
          ),
        ),
        isNull,
      );
    });

    test('powerId 未知返回 null', () {
      expect(
        normalizeStoredEstimate(
          baseRaw.copyWith(
            id: 'e1',
            cableLength: 30,
            powerId: '99kw',
            savedAt: 1754000000000,
          ),
        ),
        isNull,
      );
    });

    test('线缆越界返回 null', () {
      expect(
        normalizeStoredEstimate(
          baseRaw.copyWith(
            id: 'e1',
            cableLength: 150,
            powerId: '7kw',
            savedAt: 1754000000000,
          ),
        ),
        isNull,
      );
    });

    test('savedAt 非法返回 null', () {
      expect(
        normalizeStoredEstimate(
          baseRaw.copyWith(
            id: 'e1',
            cableLength: 30,
            powerId: '7kw',
            savedAt: 0,
          ),
        ),
        isNull,
      );
    });
  });
}
