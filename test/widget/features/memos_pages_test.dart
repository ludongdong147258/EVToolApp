import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/features/handbooks/presentation/pages/modification_compliance_page.dart';
import 'package:ev_tool_app/features/handbooks/presentation/pages/warranty_handbook_page.dart';
import 'package:ev_tool_app/features/memos/presentation/pages/inspection_memo_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> bootstrap({
    Map<String, Object> store = const {},
  }) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final localStorage = LocalStorage(prefs);
    final kv = SharedPrefsKeyValueStore(prefs);
    for (final entry in store.entries) {
      await kv.setJson(entry.key, entry.value);
    }
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localStorageProvider.overrideWithValue(localStorage),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  // 静态长列表：放大画布让 ListView 一次性构建全部子项
  // （英文字幕比中文高，需更高画布才能构建完 11 张品牌卡）
  Future<void> pumpTall(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(400, 20000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(child);
    await tester.pumpAndSettle();
  }

  group('inspection_memo_page', () {
    testWidgets('有车辆与备忘时展示计算结果各分区', (tester) async {
      final container = await bootstrap(
        store: {
          'vehicles': [
            {
              'id': 'v1',
              'name': '我的小车',
              'battery': 60,
              'note': '',
              'photoPath': '',
              'isDefault': true,
              'createdAt': 1,
              'updatedAt': 1,
            },
          ],
          'inspectionMemos': [
            {
              'id': 'm1',
              'vehicleId': 'v1',
              'vehicleName': '我的小车',
              'registrationDate': '2021-06-15',
              'mileageKm': 25000,
              'insuranceExpiryDate': null,
              'createdAt': 1,
              'updatedAt': 1,
            },
          ],
        },
      );

      await pumpTall(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InspectionMemoPage()),
        ),
      );

      // 表单回填
      expect(find.text('Memo details'), findsOneWidget);
      expect(find.text('我的小车'), findsWidgets);
      expect(find.text('2021-06-15'), findsOneWidget);
      expect(find.text('Save memo'), findsOneWidget);

      // 年检 hero + 时间轴 + 维保节点
      expect(
        find.text('Next inspection · In-person inspection'),
        findsOneWidget,
      );
      expect(find.text('Inspection timeline'), findsOneWidget);
      expect(find.text('EV maintenance milestones'), findsOneWidget);
      expect(find.text('Battery/motor/electronics check'), findsOneWidget);
      expect(find.text('Coolant check & replacement'), findsOneWidget);
      expect(find.text('Saved memos · 1'), findsOneWidget);
    });

    testWidgets('无车辆时展示去添加车辆空态', (tester) async {
      final container = await bootstrap();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InspectionMemoPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a vehicle first to set up a memo'), findsOneWidget);
      expect(find.text('Add vehicle'), findsOneWidget);
      expect(find.text('Save memo'), findsNothing);
    });

    testWidgets('车辆选择弹层支持已删车辆的孤儿备忘', (tester) async {
      final container = await bootstrap(
        store: {
          'vehicles': [
            {
              'id': 'v1',
              'name': '现役车',
              'battery': 60,
              'note': '',
              'photoPath': '',
              'isDefault': true,
              'createdAt': 1,
              'updatedAt': 1,
            },
          ],
          'inspectionMemos': [
            {
              'id': 'm2',
              'vehicleId': 'v-gone',
              'vehicleName': '幽灵车',
              'registrationDate': '2021-06-15',
              'mileageKm': 25000,
              'insuranceExpiryDate': null,
              'createdAt': 1,
              'updatedAt': 2,
            },
          ],
        },
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InspectionMemoPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('现役车'));
      await tester.pumpAndSettle();

      expect(find.text('幽灵车 · Deleted'), findsOneWidget);
      expect(find.text('现役车'), findsWidgets);
    });
  });

  group('modification_compliance_page', () {
    testWidgets('渲染全部 10 个改装项目与三类分区', (tester) async {
      await pumpTall(
        tester,
        const MaterialApp(home: ModificationCompliancePage()),
      );

      expect(find.text('Common modifications at a glance'), findsOneWidget);
      // Hero 统计、跳转 chip 与分区标题同文案（Legal / Illegal 各出现 3 次）
      expect(find.text('Legal'), findsNWidgets(3));
      expect(find.text('Legal (registration required)'), findsOneWidget);
      expect(find.text('Illegal'), findsNWidgets(3));
      for (final name in [
        'Interior modifications',
        'Small exterior decorations',
        'Same-spec wheel replacement',
        'Body color change (wrap/paint)',
        'Exterior kits (bumpers/side skirts/spoilers)',
        'Changing wheel size/spec',
        'Modifying battery/motor/electronics',
        'Suspension modifications (lift/lower)',
        'Illegal lights (strobe/added spotlights)',
        'Wider track / spacer adapters',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('Enforcement risk'), findsNWidgets(10));
    });
  });

  group('warranty_handbook_page', () {
    testWidgets('渲染全部 11 个品牌卡与国标基线', (tester) async {
      await pumpTall(tester, const MaterialApp(home: WarrantyHandbookPage()));

      expect(find.text('Warranty quick reference by brand'), findsOneWidget);
      expect(find.text('National regulatory baseline'), findsOneWidget);
      expect(find.text('Vehicle warranty'), findsNWidgets(11));
      for (final name in [
        'BYD',
        'XPeng',
        'Xiaomi',
        'Zeekr',
        'NIO',
        'Tesla',
        'Geely',
        'AITO',
        'Li Auto',
        'Leapmotor',
        'Aion',
      ]) {
        // 视口外的横向跳转 chip 不构建，只断言品牌卡名称至少出现一次
        expect(find.text(name), findsWidgets, reason: name);
      }
    });
  });
}
