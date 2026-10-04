import 'package:ev_tool_app/core/domain/fuel_ev_calc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calcAnnualCost 油电成本计算（美制）', () {
    test('默认输入计算出正确的年度成本与节省', () {
      // Arrange
      const inputs = FuelEvInputs();

      // Act
      final result = calcAnnualCost(inputs);

      // Assert
      // 燃油：13500 / 28 × 3.3 = 1591.07 → 1591
      // 电动：13500 / 3.3 × 0.16 = 654.55 → 655
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.fuelCost, 1591);
      expect(result.evCost, 655);
      expect(result.savings, 936);
      expect(result.savingPer10k, 693);
    });

    test('最小里程边界计算正确', () {
      // Arrange
      const inputs = FuelEvInputs(mileage: minMileage);

      // Act
      final result = calcAnnualCost(inputs);

      // Assert
      // 燃油：500 / 28 × 3.3 = 58.93 → 59；电动：500 / 3.3 × 0.16 = 24.24 → 24
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.fuelCost, 59);
      expect(result.evCost, 24);
      expect(result.savings, 35);
    });

    test('最大里程边界计算正确', () {
      // Arrange
      const inputs = FuelEvInputs(mileage: maxMileage);

      // Act
      final result = calcAnnualCost(inputs);

      // Assert
      // 燃油：100000 / 28 × 3.3 = 11785.71；电动：100000 / 3.3 × 0.16 = 4848.48
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.fuelCost, 11786);
      expect(result.evCost, 4848);
      expect(result.savingPer10k, 694);
    });

    test('接受字符串形式的输入（来自输入框）', () {
      // Arrange
      const inputs = FuelEvInputs(
        mileage: '13500',
        mpg: '28',
        gasPrice: '3.30',
        miPerKwh: '3.3',
        elecPrice: '0.16',
      );

      // Act
      final result = calcAnnualCost(inputs);

      // Assert
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.fuelCost, 1591);
      expect(result.evCost, 655);
    });

    test('任一参数为 0 时返回 null', () {
      // Arrange & Act
      final result = calcAnnualCost(const FuelEvInputs(gasPrice: 0));

      // Assert
      expect(result, isNull);
    });

    test('任一参数为负数时返回 null', () {
      // Arrange & Act
      final result = calcAnnualCost(const FuelEvInputs(elecPrice: -1));

      // Assert
      expect(result, isNull);
    });

    test('任一参数为空串或非数字时返回 null', () {
      // Arrange & Act
      final emptyResult = calcAnnualCost(const FuelEvInputs(mileage: ''));
      final nanResult = calcAnnualCost(const FuelEvInputs(mpg: 'abc'));
      // JS 侧 undefined 入参在 Dart 中以显式 null 表达
      final undefinedResult = calcAnnualCost(
        const FuelEvInputs(miPerKwh: null),
      );

      // Assert
      expect(emptyResult, isNull);
      expect(nanResult, isNull);
      expect(undefinedResult, isNull);
    });
  });

  group('buildShareQuery / parseShareQuery 分享参数往返', () {
    test('默认输入 round-trip 后还原为字符串输入', () {
      // Act
      final query = buildShareQuery(defaultFuelEvInputs);
      final restored = parseShareQuery(Uri.splitQueryString(query));

      // Assert
      if (restored == null) {
        fail('restored should not be null');
      }
      expect(restored.mileage, '13500');
      expect(restored.mpg, '28');
      expect(restored.gasPrice, '3.3');
      expect(restored.miPerKwh, '3.3');
      expect(restored.elecPrice, '0.16');
    });

    test('自定义输入 round-trip 后计算结果一致', () {
      // Arrange
      const inputs = FuelEvInputs(
        mileage: 20000,
        mpg: '30',
        gasPrice: '3.5',
        miPerKwh: '3.6',
        elecPrice: '0.2',
      );

      // Act
      final restored = parseShareQuery(
        Uri.splitQueryString(buildShareQuery(inputs)),
      );

      // Assert
      final a = calcAnnualCost(restored!);
      final b = calcAnnualCost(inputs)!;
      expect(a!.fuelCost, b.fuelCost);
      expect(a.evCost, b.evCost);
      expect(a.savings, b.savings);
      expect(a.savingPer10k, b.savingPer10k);
    });

    test('缺任一参数返回 null', () {
      // Act
      final restored = parseShareQuery({'m': '13500', 'fc': '28', 'fp': '3.3'});

      // Assert
      expect(restored, isNull);
    });

    test('任一参数非法（非数字/超界）返回 null', () {
      // Act & Assert
      expect(
        parseShareQuery({
          'm': 'abc',
          'fc': '28',
          'fp': '3.3',
          'ec': '3.3',
          'ep': '0.16',
        }),
        isNull,
      );
      expect(
        parseShareQuery({
          'm': '13500',
          'fc': '0',
          'fp': '3.3',
          'ec': '3.3',
          'ep': '0.16',
        }),
        isNull,
      );
      expect(
        parseShareQuery({
          'm': '-1',
          'fc': '28',
          'fp': '3.3',
          'ec': '3.3',
          'ep': '0.16',
        }),
        isNull,
      );
    });
  });

  group('buildShareTitle 分享标题', () {
    test('节省为正时标题带节省金额', () {
      // Arrange
      final result = calcAnnualCost(defaultFuelEvInputs);

      // Act
      final title = buildShareTitle(result);

      // Assert
      expect(title, 'An EV saves \$936 a year vs a gas car — here is the math');
    });

    test('电动更贵时标题切换为成本对比口径', () {
      // Arrange
      // 燃油 1591，电动 13500 / 3.3 × 9 = 36818.18 → 36818，差 35227
      final result = calcAnnualCost(const FuelEvInputs(elecPrice: 9));

      // Act
      final title = buildShareTitle(result);

      // Assert
      expect(title, '\$35,227 a year apart — run your own numbers');
    });

    test('结果为空时返回兜底标题', () {
      // Act & Assert
      expect(
        buildShareTitle(null),
        'Fuel vs EV cost · see your annual savings in one minute',
      );
    });
  });
}
