import 'package:ev_tool_app/core/domain/fuel_ev_calc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calcAnnualCost 油电成本计算', () {
    test('默认输入计算出正确的年度成本与节省', () {
      // Arrange
      const inputs = FuelEvInputs();

      // Act
      final result = calcAnnualCost(inputs);

      // Assert
      // 燃油：15000/100 × 8.5 × 8.0 = 10200
      // 电动：15000/100 × 15 × 1.2 = 2700
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.fuelCost, 10200);
      expect(result.evCost, 2700);
      expect(result.savings, 7500);
      expect(result.savingPer10k, 5000);
    });

    test('最小里程边界计算正确', () {
      // Arrange
      const inputs = FuelEvInputs(mileage: minMileage);

      // Act
      final result = calcAnnualCost(inputs);

      // Assert
      // 燃油：1000/100 × 8.5 × 8.0 = 680；电动：1000/100 × 15 × 1.2 = 180
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.fuelCost, 680);
      expect(result.evCost, 180);
      expect(result.savings, 500);
    });

    test('最大里程边界计算正确', () {
      // Arrange
      const inputs = FuelEvInputs(mileage: maxMileage);

      // Act
      final result = calcAnnualCost(inputs);

      // Assert
      // 燃油：200000/100 × 8.5 × 8.0 = 136000；电动：200000/100 × 15 × 1.2 = 36000
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.fuelCost, 136000);
      expect(result.evCost, 36000);
      expect(result.savingPer10k, 5000);
    });

    test('接受字符串形式的输入（来自输入框）', () {
      // Arrange
      const inputs = FuelEvInputs(
        mileage: '15000',
        fuelConsumption: '8.5',
        fuelPrice: '8.0',
        evConsumption: '15.0',
        elecPrice: '1.2',
      );

      // Act
      final result = calcAnnualCost(inputs);

      // Assert
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.fuelCost, 10200);
      expect(result.evCost, 2700);
    });

    test('任一参数为 0 时返回 null', () {
      // Arrange & Act
      final result = calcAnnualCost(const FuelEvInputs(fuelPrice: 0));

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
      final nanResult = calcAnnualCost(
        const FuelEvInputs(fuelConsumption: 'abc'),
      );
      // JS 侧 undefined 入参在 Dart 中以显式 null 表达
      final undefinedResult = calcAnnualCost(
        const FuelEvInputs(evConsumption: null),
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
      expect(restored.mileage, '15000');
      expect(restored.fuelConsumption, '8.5');
      expect(restored.fuelPrice, '8');
      expect(restored.evConsumption, '15');
      expect(restored.elecPrice, '1.2');
    });

    test('自定义输入 round-trip 后计算结果一致', () {
      // Arrange
      const inputs = FuelEvInputs(
        mileage: 20000,
        fuelConsumption: '9.2',
        fuelPrice: '7.5',
        evConsumption: '14',
        elecPrice: '0.8',
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
      final restored = parseShareQuery({'m': '15000', 'fc': '8.5', 'fp': '8'});

      // Assert
      expect(restored, isNull);
    });

    test('任一参数非法（非数字/超界）返回 null', () {
      // Act & Assert
      expect(
        parseShareQuery({
          'm': 'abc',
          'fc': '8.5',
          'fp': '8',
          'ec': '15',
          'ep': '1.2',
        }),
        isNull,
      );
      expect(
        parseShareQuery({
          'm': '15000',
          'fc': '0',
          'fp': '8',
          'ec': '15',
          'ep': '1.2',
        }),
        isNull,
      );
      expect(
        parseShareQuery({
          'm': '-1',
          'fc': '8.5',
          'fp': '8',
          'ec': '15',
          'ep': '1.2',
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
      expect(title, '开电车一年比油车省 ¥7,500，帮你算好了');
    });

    test('电动更贵时标题切换为成本对比口径', () {
      // Arrange
      // 燃油 10200，电动 150 × 15 × 9 = 20250，差 10050
      final result = calcAnnualCost(const FuelEvInputs(elecPrice: 9));

      // Act
      final title = buildShareTitle(result);

      // Assert
      expect(title, '油电一年成本差 ¥10,050，进来算算你的');
    });

    test('结果为空时返回兜底标题', () {
      // Act & Assert
      expect(buildShareTitle(null), '油电成本对比 · 一分钟算出开电车能省多少');
    });
  });
}
