import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ev_tool_app/core/routing/route_names.dart';
import 'package:ev_tool_app/core/widgets/app_error_widget.dart';
import 'package:ev_tool_app/core/widgets/main_shell.dart';
import 'package:ev_tool_app/features/costs/presentation/pages/cost_add_page.dart';
import 'package:ev_tool_app/features/costs/presentation/pages/cost_report_page.dart';
import 'package:ev_tool_app/features/equipment/presentation/pages/equipment_page.dart';
import 'package:ev_tool_app/features/maps/presentation/pages/charge_map_page.dart';
import 'package:ev_tool_app/features/maps/presentation/pages/location_picker_page.dart';
import 'package:ev_tool_app/features/costs/presentation/pages/cost_list_page.dart';
import 'package:ev_tool_app/features/handbooks/presentation/pages/modification_compliance_page.dart';
import 'package:ev_tool_app/features/handbooks/presentation/pages/warranty_handbook_page.dart';
import 'package:ev_tool_app/features/memos/presentation/pages/inspection_memo_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/about_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/agreement_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/backup_restore_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/privacy_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/profile_page.dart';
import 'package:ev_tool_app/features/records/presentation/pages/record_add_page.dart';
import 'package:ev_tool_app/features/records/presentation/pages/records_page.dart';
import 'package:ev_tool_app/features/tools/presentation/pages/fuel_ev_calc_page.dart';
import 'package:ev_tool_app/features/tools/presentation/pages/home_charger_calc_page.dart';
import 'package:ev_tool_app/features/tools/presentation/pages/peak_valley_calc_page.dart';
import 'package:ev_tool_app/features/tools/presentation/pages/range_calc_page.dart';
import 'package:ev_tool_app/features/stations/presentation/pages/nearby_stations_page.dart';
import 'package:ev_tool_app/features/stats/presentation/pages/annual_report_page.dart';
import 'package:ev_tool_app/features/stats/presentation/pages/charge_stats_page.dart';
import 'package:ev_tool_app/features/tools/presentation/pages/tools_page.dart';
import 'package:ev_tool_app/features/vehicles/presentation/pages/vehicles_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/settings_page.dart';

/// 全量本地应用，无登录守卫；auth 代码保留但未挂载（见 access_guard.dart）。
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteNames.records,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(shell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.records,
                name: 'records',
                builder: (context, state) => const RecordsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.costs,
                name: 'costs',
                builder: (context, state) => const CostListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.tools,
                name: 'tools',
                builder: (context, state) => const ToolsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.profile,
                name: 'profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      ..._subRoutes(),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: AppErrorWidget(
        message: 'Page not found: ${state.error}',
        onRetry: () => context.go(RouteNames.records),
      ),
    ),
  );
});

/// push 子页（逐阶段由 FeaturePlaceholderPage 替换为真实页面）。
List<GoRoute> _subRoutes() {
  return [
    GoRoute(
      path: RouteNames.recordAdd,
      name: 'record-add',
      builder: (context, state) =>
          RecordAddPage(recordId: state.uri.queryParameters['id']),
    ),
    GoRoute(
      path: RouteNames.chargeStats,
      name: 'charge-stats',
      builder: (context, state) => const ChargeStatsPage(),
    ),
    GoRoute(
      path: RouteNames.annualReport,
      name: 'annual-report',
      builder: (context, state) => const AnnualReportPage(),
    ),
    GoRoute(
      path: RouteNames.chargeMap,
      name: 'charge-map',
      builder: (context, state) => const ChargeMapPage(),
    ),
    GoRoute(
      path: RouteNames.locationPicker,
      name: 'location-picker',
      builder: (context, state) {
        final extra = state.extra;
        final initial = extra is PickedLocation ? extra : null;
        return LocationPickerPage(
          initialLatitude: initial?.latitude,
          initialLongitude: initial?.longitude,
        );
      },
    ),
    GoRoute(
      path: RouteNames.costAdd,
      name: 'cost-add',
      builder: (context, state) =>
          CostAddPage(expenseId: state.uri.queryParameters['id']),
    ),
    GoRoute(
      path: RouteNames.costReport,
      name: 'cost-report',
      builder: (context, state) => const CostReportPage(),
    ),
    GoRoute(
      path: RouteNames.vehicles,
      name: 'vehicles',
      builder: (context, state) => const VehiclesPage(),
    ),
    GoRoute(
      path: RouteNames.inspectionMemo,
      name: 'inspection-memo',
      builder: (context, state) => const InspectionMemoPage(),
    ),
    GoRoute(
      path: RouteNames.fuelEvCalc,
      name: 'fuel-ev-calc',
      builder: (context, state) => const FuelEvCalcPage(),
    ),
    GoRoute(
      path: RouteNames.rangeCalc,
      name: 'range-calc',
      builder: (context, state) => const RangeCalcPage(),
    ),
    GoRoute(
      path: RouteNames.peakValleyCalc,
      name: 'peak-valley-calc',
      builder: (context, state) => const PeakValleyCalcPage(),
    ),
    GoRoute(
      path: RouteNames.homeChargerCalc,
      name: 'home-charger-calc',
      builder: (context, state) => const HomeChargerCalcPage(),
    ),
    GoRoute(
      path: RouteNames.nearbyStations,
      name: 'nearby-stations',
      builder: (context, state) => const NearbyStationsPage(),
    ),
    GoRoute(
      path: RouteNames.modificationCompliance,
      name: 'modification-compliance',
      builder: (context, state) => const ModificationCompliancePage(),
    ),
    GoRoute(
      path: RouteNames.warrantyHandbook,
      name: 'warranty-handbook',
      builder: (context, state) => const WarrantyHandbookPage(),
    ),
    GoRoute(
      path: RouteNames.equipment,
      name: 'equipment',
      builder: (context, state) => const EquipmentPage(),
    ),
    GoRoute(
      path: RouteNames.backupRestore,
      name: 'backup-restore',
      builder: (context, state) => const BackupRestorePage(),
    ),
    GoRoute(
      path: RouteNames.settings,
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: RouteNames.about,
      name: 'about',
      builder: (context, state) => const AboutPage(),
    ),
    GoRoute(
      path: RouteNames.agreement,
      name: 'agreement',
      builder: (context, state) => const AgreementPage(),
    ),
    GoRoute(
      path: RouteNames.privacy,
      name: 'privacy',
      builder: (context, state) => const PrivacyPage(),
    ),
  ];
}
