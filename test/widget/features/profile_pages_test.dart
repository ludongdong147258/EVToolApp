import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/about_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/agreement_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/backup_restore_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/privacy_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/profile_page.dart';
import 'package:ev_tool_app/features/vehicles/presentation/pages/vehicles_page.dart';

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

  /// 内容较长的页面：放大画布让 ListView 一次性构建全部子项。
  Future<void> pumpTall(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(child);
    await tester.pumpAndSettle();
  }

  /// 两条充电记录 + 一辆默认车的本地数据。
  Map<String, Object> seedStore() {
    return <String, Object>{
      'chargeRecords': [
        {
          'id': 'r1',
          'type': 'fast',
          'date': '2026-09-01',
          'cost': 30,
          'energy': 40,
          'createdAt': 1,
        },
        {
          'id': 'r2',
          'type': 'home',
          'date': '2026-09-15',
          'cost': 15,
          'energy': 25,
          'createdAt': 2,
        },
      ],
      'vehicles': [
        {
          'id': 'v1',
          'name': '小白',
          'battery': 60,
          'note': '白色 Model 3',
          'photoPath': '',
          'isDefault': true,
          'createdAt': 1,
          'updatedAt': 1,
        },
      ],
      'userProfile': {'nickname': '阿明', 'avatarUrl': ''},
    };
  }

  group('profile_page', () {
    testWidgets('渲染用户卡（昵称/徽标/记录天数/统计）与全部菜单', (tester) async {
      final container = await bootstrap(store: seedStore());

      await pumpTall(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProfilePage()),
        ),
      );

      // 用户卡：昵称 + 等级徽标 + 记录天数 + 累计花费
      expect(find.text('阿明'), findsOneWidget);
      expect(find.text('Rookie Owner'), findsOneWidget);
      expect(find.text('2 days logged'), findsOneWidget);
      expect(find.text(r'Total spent $45.00'), findsOneWidget);

      // 三列统计
      expect(find.text('Records'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Energy'), findsOneWidget);

      // 菜单
      expect(find.text('My Services'), findsOneWidget);
      expect(find.text('My Vehicles'), findsOneWidget);
      expect(find.text('Charge Stats'), findsOneWidget);
      expect(find.text('Charging Map'), findsOneWidget);
      expect(find.text('Backup & Restore'), findsOneWidget);
      expect(find.text('About the App'), findsOneWidget);
      expect(find.text('Theme Colors'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('主题配色菜单打开 6 套配色弹层', (tester) async {
      final container = await bootstrap(store: seedStore());

      await pumpTall(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProfilePage()),
        ),
      );

      await tester.tap(find.text('Theme Colors'));
      await tester.pumpAndSettle();

      expect(find.text('Aurora Green'), findsOneWidget);
      expect(find.text('Deep Blue'), findsOneWidget);
      expect(find.text('Sunset Orange'), findsOneWidget);
      expect(find.text('Stellar Purple'), findsOneWidget);
      expect(find.text('Sakura Pink'), findsOneWidget);
      expect(find.text('Cyber Cyan'), findsOneWidget);
    });
  });

  group('backup_restore_page', () {
    testWidgets('渲染导出/导入分区与数据概要', (tester) async {
      final container = await bootstrap(store: seedStore());

      await pumpTall(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BackupRestorePage()),
        ),
      );

      // 分区标题与按钮同名，各出现两次
      expect(find.text('Export Data'), findsNWidgets(2));
      expect(find.text('Copy Backup Text'), findsNothing);
      expect(find.text('Import Backup'), findsNWidgets(2));
      expect(find.textContaining('2 charging records'), findsOneWidget);
      expect(find.textContaining('1 vehicle(s)'), findsOneWidget);
      expect(find.textContaining('0 expense(s)'), findsOneWidget);
      expect(find.textContaining('0 inspection memo(s)'), findsOneWidget);
    });
  });

  group('vehicles_page', () {
    testWidgets('渲染车库卡片并打开添加车辆弹层', (tester) async {
      final container = await bootstrap(store: seedStore());

      await pumpTall(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VehiclesPage()),
        ),
      );

      // 车库卡片：昵称 + 默认徽标 + 容量 + 备注 + 添加入口
      expect(find.text('小白'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(find.text('白色 Model 3'), findsOneWidget);
      expect(find.text('Add Vehicle'), findsOneWidget);

      // 打开添加弹层：表单字段齐全
      await tester.tap(find.text('Add Vehicle'));
      await tester.pumpAndSettle();

      expect(find.text('Nickname'), findsOneWidget);
      expect(find.text('Battery (kWh)'), findsOneWidget);
      expect(find.text('Note (Optional)'), findsOneWidget);
      expect(find.text('Photo (Optional)'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Library'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('空车库展示空态与 CTA', (tester) async {
      final container = await bootstrap();

      await pumpTall(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VehiclesPage()),
        ),
      );

      expect(find.text('No vehicles yet'), findsOneWidget);
      expect(
        find.text('Add a vehicle to track your charging costs'),
        findsOneWidget,
      );
    });
  });

  group('about_page', () {
    testWidgets('渲染品牌区/简介/信息列表', (tester) async {
      await pumpTall(tester, const MaterialApp(home: AboutPage()));

      expect(find.text('VoltLedger · EV Toolkit'), findsOneWidget);
      expect(find.text('Contact Email'), findsNothing);
      expect(find.text('User Agreement'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('1.0.0'), findsOneWidget);
    });
  });

  group('legal_pages', () {
    testWidgets('用户协议页渲染更新日期与首章节', (tester) async {
      await pumpTall(tester, const MaterialApp(home: AgreementPage()));

      expect(find.text('Last updated: 2026-08-23'), findsOneWidget);
      expect(find.text('1. Acceptance of These Terms'), findsOneWidget);
    });

    testWidgets('隐私政策页渲染更新日期与首章节', (tester) async {
      await pumpTall(tester, const MaterialApp(home: PrivacyPage()));

      expect(find.text('Last updated: 2026-08-23'), findsOneWidget);
      expect(find.text('1. Introduction'), findsOneWidget);
    });
  });
}
