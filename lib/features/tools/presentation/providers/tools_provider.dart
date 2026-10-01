import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/home_charger_calc.dart';
import 'package:ev_tool_app/core/domain/recent_tools.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/features/tools/data/repositories/estimate_repository.dart';
import 'package:ev_tool_app/features/tools/data/repositories/tool_usage_repository.dart';

/// 最近使用的工具 id 状态（存储即真相，返回工具页时 reload）。
class RecentToolsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    return ref.watch(toolUsageRepositoryProvider).getRecentToolIds();
  }

  ToolUsageRepository get _repo => ref.read(toolUsageRepositoryProvider);

  void reload() {
    state = _repo.getRecentToolIds();
  }

  /// 记录一次使用（置顶去重，保留最近 3 个）。
  ///
  /// 写失败静默（非关键数据），state 立即按本地值更新。
  void track(String toolId) {
    unawaited(_repo.trackToolUse(toolId));
    state = pushRecentTool(state, toolId);
  }
}

final recentToolsProvider = NotifierProvider<RecentToolsNotifier, List<String>>(
  RecentToolsNotifier.new,
);

/// 已保存的私桩测算状态。
class EstimatesNotifier extends Notifier<List<StoredEstimate>> {
  @override
  List<StoredEstimate> build() {
    return ref.watch(estimateRepositoryProvider).getEstimates();
  }

  EstimateRepository get _repo => ref.read(estimateRepositoryProvider);

  void reload() {
    state = _repo.getEstimates();
  }

  /// 保存当前测算（前插，上限 20 条）；保存失败抛异常由页面 toast。
  Future<void> save({
    required int cableLength,
    required String powerId,
    required String spot,
    required Map<String, bool> conditions,
    required InstallEstimate estimate,
  }) async {
    final entry = StoredEstimate(
      id: generateId(),
      cableLength: cableLength,
      powerId: powerId,
      spot: spot,
      conditions: conditions,
      estimate: estimate,
      savedAt: DateTime.now().millisecondsSinceEpoch,
    );
    state = await _repo.saveEstimate(entry);
  }

  /// 按 id 删除（幂等）。
  Future<void> remove(String id) async {
    state = await _repo.removeEstimate(id);
  }
}

final estimatesProvider =
    NotifierProvider<EstimatesNotifier, List<StoredEstimate>>(
      EstimatesNotifier.new,
    );
