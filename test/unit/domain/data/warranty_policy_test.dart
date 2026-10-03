import 'package:ev_tool_app/core/domain/data/warranty_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fieldIds = warrantyFields.map((field) => field.id).toList();

  group('warrantyPolicy 静态数据完整性', () {
    test('所有品牌 id 唯一且必填字段完整', () {
      // Arrange
      final ids = warrantyBrands.map((brand) => brand.id).toList();
      // Act & Assert
      expect(ids.toSet().length, warrantyBrands.length);
      for (final brand in warrantyBrands) {
        expect(brand.id, isNotEmpty);
        expect(brand.name, isNotEmpty);
        expect(brand.tagline, isNotEmpty);
        expect(brand.offersLifetimeWarranty, isA<bool>());
        expect(brand.hasDegradationStandard, isA<bool>());
        expect(brand.voidsLifetimeOnTransfer, isA<bool>());
        expect(brand.summary.vehicle.length, greaterThan(0));
        expect(brand.summary.powertrain.length, greaterThan(0));
      }
    });

    test('每个品牌 fields 恰好覆盖全部六个字段且值非空', () {
      // Act & Assert
      for (final brand in warrantyBrands) {
        expect(brand.fields.keys.toList()..sort(), [...fieldIds]..sort());
        for (final fieldId in fieldIds) {
          expect(brand.fields[fieldId]!.length, greaterThan(0));
        }
      }
    });

    test('warrantyFields 恰好六项、id 唯一且 label/icon 非空', () {
      // Act & Assert
      expect(warrantyFields, hasLength(6));
      expect(fieldIds.toSet().length, fieldIds.length);
      for (final field in warrantyFields) {
        expect(field.id, isNotEmpty);
        expect(field.label, isNotEmpty);
        expect(field.icon, isNotEmpty);
      }
    });

    test('免责声明非空且注明仅供参考', () {
      // Act & Assert
      expect(warrantyDisclaimer.length, greaterThan(0));
      expect(warrantyDisclaimer, contains('For reference only'));
    });

    test('数据日期为 YYYY-MM 格式且免责声明包含该日期', () {
      // Act & Assert
      expect(RegExp(r'^\d{4}-\d{2}$').hasMatch(warrantyDataDate), isTrue);
      expect(warrantyDisclaimer, contains(warrantyDataDate));
    });

    test('warrantyBaseline 结构完整：标题/说明非空且规则条目字段齐全', () {
      // Act & Assert
      expect(warrantyBaseline.title.length, greaterThan(0));
      expect(warrantyBaseline.note.length, greaterThan(0));
      expect(warrantyBaseline.rules.length, greaterThanOrEqualTo(3));
      for (final rule in warrantyBaseline.rules) {
        expect(rule.icon, isNotEmpty);
        expect(rule.label, isNotEmpty);
        expect(rule.text.length, greaterThan(0));
      }
    });
  });

  group('getBrandById 按品牌 id 取品牌', () {
    test('命中返回对应品牌对象', () {
      // Arrange
      const id = 'tesla';
      // Act
      final brand = getBrandById(id);
      // Assert
      expect(brand, isNotNull);
      expect(brand!.id, id);
      expect(brand.name, 'Tesla');
    });

    test('未知 id 返回 null', () {
      // Act & Assert
      expect(getBrandById('unknown'), isNull);
    });

    test('全部品牌 id 均可通过 getBrandById 取回', () {
      // Act & Assert
      for (final brand in warrantyBrands) {
        expect(getBrandById(brand.id), same(brand));
      }
    });
  });
}
