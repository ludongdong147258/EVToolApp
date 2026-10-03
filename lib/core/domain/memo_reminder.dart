/// 备忘到期提醒（纯函数）
///
/// 汇总多条年检维保备忘的到期状态，产出一条最紧急的提醒文案，
/// 供首页提醒条与 BottomNav 红点消费。约定与 lib/ 一致：
/// 非法输入返回 null，绝不抛错。
library;

import 'package:ev_tool_app/core/domain/inspection_memo_calc.dart';

/// 备忘保存/删除后的广播事件名（memoService 触发，BottomNav 订阅刷新红点）
const String memoChangeEvent = 'memoChange';

/* 候选类别优先级：同为紧急程度时日期类（年检/保险）先于维保节点 */
const Map<String, int> _categoryRank = {
  'inspection': 0,
  'insurance': 1,
  'maintenance': 2,
};

/// 已过期节点的提醒宽限（超过 90 天视为陈年旧账不再刷屏，只提醒下一节点）
const int _overdueGraceDays = 90;

/// 提醒级别：overdue 已到期 / soon 即将到期
class MemoReminder {
  const MemoReminder({required this.level, required this.text});

  final String level;
  final String text;
}

/// 到期天数 → 英文后缀（-3 → "3 days overdue"；0 → "due today"；5 → "due in 5 days"）
String _buildDueSuffix(int daysRemaining) {
  if (daysRemaining < 0) {
    return '${-daysRemaining} days overdue';
  }
  if (daysRemaining == 0) {
    return 'due today';
  }
  return 'due in $daysRemaining days';
}

/// 单条备忘的候选提醒（order 用于保证排序稳定性，等价 JS 稳定 sort）
class _Candidate {
  const _Candidate({
    required this.category,
    required this.dueIn,
    required this.text,
    required this.order,
  });

  final String category;
  final int dueIn;
  final String text;
  final int order;
}

/// 单条备忘 → 候选提醒列表（仅收集 soon/overdue 项）
List<_Candidate> _buildCandidates(MemoItem memo, DateTime now) {
  final prefix = memo.vehicleName.isNotEmpty ? '${memo.vehicleName} · ' : '';
  final candidates = <_Candidate>[];

  final schedule = calcInspectionSchedule(memo.registrationDate, now);
  if (schedule != null) {
    /* 下一节点 30 天内临近提醒；最近已过期节点仅在宽限期内提醒（陈年旧账不刷屏） */
    for (final node in [schedule.latestPast, schedule.next]) {
      if (node == null) {
        continue;
      }
      final isNext = identical(node, schedule.next);
      final inWindow = isNext
          ? node.daysRemaining <= 30
          : node.daysRemaining >= -_overdueGraceDays;
      if (inWindow) {
        candidates.add(
          _Candidate(
            order: candidates.length,
            category: 'inspection',
            dueIn: node.daysRemaining,
            text:
                '$prefix${node.typeLabel} ${_buildDueSuffix(node.daysRemaining)}',
          ),
        );
      }
    }
  }

  final insurance = calcInsuranceStatus(memo.insuranceExpiryDate, now);
  if (insurance != null && insurance.status != statusNormal) {
    candidates.add(
      _Candidate(
        order: candidates.length,
        category: 'insurance',
        dueIn: insurance.daysRemaining,
        text:
            '${prefix}Car insurance ${_buildDueSuffix(insurance.daysRemaining)}',
      ),
    );
  }

  final nodes = calcMaintenanceNodes(
    memo.registrationDate,
    memo.mileageKm,
    now,
  );
  if (nodes != null) {
    for (final node in nodes) {
      if (node.status == statusNormal) {
        continue;
      }
      final kmRemaining = node.kmRemaining;
      final isKmDue = kmRemaining != null && kmRemaining <= 0;
      candidates.add(
        _Candidate(
          order: candidates.length,
          category: 'maintenance',
          dueIn: isKmDue ? -1 : node.daysRemaining,
          text: isKmDue
              ? '$prefix${node.label}: service mileage reached'
              : '$prefix${node.label} ${_buildDueSuffix(node.daysRemaining)}',
        ),
      );
    }
  }
  return candidates;
}

/// 挑选最紧急的一条备忘提醒（dueIn 最小者，同值按类别优先级）
///
/// level：overdue 已到期 / soon 即将到期；无到期项返回 null
MemoReminder? pickMemoReminder(List<MemoItem?>? memos, [DateTime? now]) {
  if (memos == null || memos.isEmpty) {
    return null;
  }
  final all = <_Candidate>[];
  final currentTime = now ?? DateTime.now();
  for (final memo in memos) {
    if (memo == null) {
      continue;
    }
    all.addAll(_buildCandidates(memo, currentTime));
  }
  if (all.isEmpty) {
    return null;
  }
  all.sort((a, b) {
    final byDueIn = a.dueIn.compareTo(b.dueIn);
    if (byDueIn != 0) {
      return byDueIn;
    }
    final byCategory =
        (_categoryRank[a.category] ?? 0) - (_categoryRank[b.category] ?? 0);
    if (byCategory != 0) {
      return byCategory;
    }
    return a.order.compareTo(b.order);
  });
  final top = all.first;
  return MemoReminder(
    level: top.dueIn < 0 ? statusOverdue : statusSoon,
    text: top.text,
  );
}
