/// 用户徽标（纯函数）
///
/// 移植自 EVTool 小程序 src/lib/userBadges.js。
/// 「我的」页昵称旁的成长展示：按累计充电记录条数分档的等级徽标，
/// 以及按日去重的累计记录天数。数据全部现算，不落存储。
library;

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/date_utils.dart';

/// 徽标档位（min 升序，取满足 recordCount >= min 的最后一档）
class BadgeTier {
  const BadgeTier({required this.min, required this.label});

  /// 达到该档所需的最少记录条数
  final int min;

  /// 档位展示文案
  final String label;
}

/// 等级档位表（升序）
// ignore: constant_identifier_names
const List<BadgeTier> BADGE_TIERS = <BadgeTier>[
  BadgeTier(min: 0, label: '见习车主'),
  BadgeTier(min: 10, label: '充电达人'),
  BadgeTier(min: 50, label: '资深车主'),
  BadgeTier(min: 200, label: '元老车主'),
];

/// 安全计数：仅接受有限正数（宽松字符串如 "10abc" 不解析，防脏输入意外晋级）
int _safeCount(Object? recordCount) {
  if (recordCount is num && !recordCount.isNaN && recordCount > 0) {
    return recordCount.floor();
  }
  return 0;
}

/// 记录条数 → 等级徽标文案
///
/// 非法输入兜底最低档「见习车主」。
String resolveBadgeLabel(Object? recordCount) {
  final safeCount = _safeCount(recordCount);
  var label = BADGE_TIERS[0].label;
  for (final tier in BADGE_TIERS) {
    if (safeCount >= tier.min) {
      label = tier.label;
    }
  }
  return label;
}

/// 距下一档徽标的进度（首页「再记 N 条升为 X」进度钩子）
///
/// 已达最高档（元老车主）返回 null。
BadgeProgress? buildBadgeProgress(Object? recordCount) {
  final safeCount = _safeCount(recordCount);
  for (final tier in BADGE_TIERS) {
    if (safeCount < tier.min) {
      return BadgeProgress(
        nextLabel: tier.label,
        remaining: tier.min - safeCount,
      );
    }
  }
  return null;
}

/// 徽标进度
class BadgeProgress {
  const BadgeProgress({required this.nextLabel, required this.remaining});

  /// 下一档文案
  final String nextLabel;

  /// 还差条数
  final int remaining;

  @override
  bool operator ==(Object other) {
    return other is BadgeProgress &&
        other.nextLabel == nextLabel &&
        other.remaining == remaining;
  }

  @override
  int get hashCode => Object.hash(nextLabel, remaining);
}

/// 累计记录天数：有充电记录的日期去重计数
///
/// 空 / 脏数据返回 0。
int getRecordDays(List<ChargeRecord>? records) {
  if (records == null) {
    return 0;
  }
  final days = <String>{};
  for (final record in records) {
    final date = record.date;
    if (isValidDateString(date)) {
      days.add(date);
    }
  }
  return days.length;
}
