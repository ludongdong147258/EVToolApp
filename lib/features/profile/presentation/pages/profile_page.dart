import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/domain/theme_colors.dart';
import 'package:ev_tool_app/core/domain/user_badges.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/domain/user_profile.dart'
    show nicknameMaxLength;
import 'package:ev_tool_app/core/routing/route_names.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/theme/theme_settings.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/core/widgets/app_primary_button.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart';
import 'package:ev_tool_app/core/widgets/gradient_hero_card.dart';
import 'package:ev_tool_app/core/widgets/main_shell.dart';
import 'package:ev_tool_app/features/profile/data/repositories/user_profile_repository.dart';
import 'package:ev_tool_app/features/profile/presentation/widgets/accent_swatch.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart';

/// 昵称兜底文案（用户未设置昵称时显示）。
const String _nicknameFallback = 'EV Owner';

/// 我的页（Tab 3）：渐变用户卡 + 统计 + 功能菜单 + 主题配色弹层。
///
/// 移植小程序 src/pages/profile/index.js；意见反馈（微信客服）
/// 与广告位按决策裁剪。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _openThemePicker(BuildContext context) {
    showAppSheet(
      context: context,
      title: 'Theme Colors',
      builder: (_) => Consumer(
        builder: (context, sheetRef, _) {
          final accentId = sheetRef.watch(themeSettingsProvider).accentId;
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            // 一行固定 3 个（6 套 accent = 2 行），等宽分布
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < accentThemes.length; i += 3) ...[
                  if (i > 0) const SizedBox(height: 16),
                  Row(
                    children: [
                      for (final accent in accentThemes.skip(i).take(3))
                        Expanded(
                          child: Center(
                            child: AccentSwatch(
                              accent: accent,
                              isSelected: accent.id == accentId,
                              onTap: () {
                                sheetRef
                                    .read(themeSettingsProvider.notifier)
                                    .setAccentId(accent.id);
                                showAppToast(context, 'Applied');
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openProfileEditor(BuildContext context) {
    return showAppSheet(
      context: context,
      title: 'Edit Profile',
      builder: (_) => const _ProfileEditorSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final records = ref.watch(recordsProvider);
    final total = calcTotalSummary(records);
    final month = calcMonthSummary(records, getCurrentMonthKey());
    final badgeLabel = resolveBadgeLabel(records.length);
    final recordDays = getRecordDays(records);
    final nickname = profile.nickname ?? '';
    final displayName = nickname.isEmpty ? _nicknameFallback : nickname;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: kBottomNavScrollPadding,
        ),
        children: [
          GradientHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  onTap: () => _openProfileEditor(context),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          _ProfileAvatar(avatarUrl: profile.avatarUrl),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: AppColors.onPrimaryA22,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(child: _HeroBadge(label: badgeLabel)),
                                if (recordDays > 0) ...[
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: _HeroBadge(
                                      label: '$recordDays days logged',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total spent ${formatMoney(total.totalCost)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.onPrimaryA85,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                HeroStatsRow(
                  items: [
                    HeroStatItem(
                      label: 'Charge Records',
                      value: '${total.count}',
                    ),
                    HeroStatItem(label: 'This Month', value: '${month.count}'),
                    HeroStatItem(
                      label: 'Total Energy',
                      value: formatYuan(total.totalEnergy),
                      unit: 'kWh',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _MenuGroup(
            title: 'My Services',
            items: [
              _MenuItem(
                icon: Icons.directions_car_rounded,
                text: 'My Vehicles',
                onTap: (context) => context.push(RouteNames.vehicles),
              ),
              _MenuItem(
                icon: Icons.insights_rounded,
                text: 'Charge Stats',
                onTap: (context) => context.push(RouteNames.chargeStats),
              ),
              _MenuItem(
                icon: Icons.place_rounded,
                text: 'Charging Map',
                onTap: (context) => context.push(RouteNames.chargeMap),
              ),
              _MenuItem(
                icon: Icons.save_rounded,
                text: 'Backup & Restore',
                onTap: (context) => context.push(RouteNames.backupRestore),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MenuGroup(
            title: 'About the App',
            items: [
              _MenuItem(
                icon: Icons.tune_rounded,
                text: 'Theme Colors',
                onTap: _openThemePicker,
              ),
              _MenuItem(
                icon: Icons.info_rounded,
                text: 'About',
                onTap: (context) => context.push(RouteNames.about),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// hero 卡昵称旁的小徽标（半透明白底）。
class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.onPrimaryA22,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      // 英文徽标文案更长：窄屏下单行缩放，避免溢出
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 用户头像：avatarUrl 为裸文件名，经头像存储解析渲染；
/// 无头像 / 存储未就绪时回退人像图标。
///
/// hero 绿卡用半透明白回退（对齐小程序）；白底弹窗（编辑资料）
/// 需传 [useBrandFallback] 用品牌渐变默认头像，否则白底白字不可见。
class _ProfileAvatar extends ConsumerWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    this.useBrandFallback = false,
  });

  final String avatarUrl;
  final bool useBrandFallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget fallback() => useBrandFallback
        ? Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.palette.primary,
                  context.palette.primaryContainer,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 32,
              color: Colors.white,
            ),
          )
        : Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.onPrimaryA22,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 32,
              color: Colors.white,
            ),
          );
    if (avatarUrl.isEmpty) {
      return fallback();
    }
    final store = ref.watch(avatarPhotoStoreProvider);
    final resolved = store.valueOrNull;
    if (resolved == null || !resolved.exists(avatarUrl)) {
      return fallback();
    }
    return ClipOval(
      child: Image.file(
        File(resolved.resolvePath(avatarUrl)),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      ),
    );
  }
}

/// 单个功能卡片（图标在上、文字在下）。
class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final void Function(BuildContext context) onTap;
}

/// 分组：小标题 + 两列卡片网格。
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.title, required this.items});

  final String title;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cardWidth = (context.screenWidth - 32 - 12) / 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: context.textTheme.titleSmall?.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: cardWidth,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppColors.radiusLg),
                    onTap: () => item.onTap(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        children: [
                          Icon(item.icon, size: 22, color: palette.primary),
                          const SizedBox(height: 6),
                          Text(
                            item.text,
                            style: TextStyle(
                              fontSize: 13,
                              color: palette.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 资料编辑弹层：头像（选图后立即保存生效）+ 昵称。
class _ProfileEditorSheet extends ConsumerStatefulWidget {
  const _ProfileEditorSheet();

  @override
  ConsumerState<_ProfileEditorSheet> createState() =>
      _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends ConsumerState<_ProfileEditorSheet> {
  late final TextEditingController _nicknameCtrl = TextEditingController(
    text: ref.read(userProfileProvider).nickname ?? '',
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  /// 从相册选头像：临时文件转持久文件并立即生效展示。
  Future<void> _pickAvatar() async {
    if (_isSaving) return;
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 90,
      );
      if (picked == null) return; // 用户取消不算错误
      setState(() => _isSaving = true);
      await ref.read(userProfileProvider.notifier).saveAvatar(picked.path);
      if (mounted) showAppToast(context, 'Avatar updated');
    } on Exception catch (e) {
      appLogger.e('Failed to pick avatar: $e');
      if (mounted) showAppToast(context, 'Failed to save avatar');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 保存昵称（清空视为恢复默认昵称）。
  Future<void> _saveNickname() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(userProfileProvider.notifier)
          .saveNickname(_nicknameCtrl.text);
      if (mounted) {
        Navigator.of(context).pop();
        showAppToast(context, 'Saved');
      }
    } on Exception {
      if (mounted) showAppToast(context, 'Save failed, please try again');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final profile = ref.watch(userProfileProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: Column(
              children: [
                Stack(
                  children: [
                    _ProfileAvatar(
                      avatarUrl: profile.avatarUrl,
                      useBrandFallback: true,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: AppColors.onPrimaryA22,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to change avatar',
                  style: TextStyle(fontSize: 12, color: palette.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nickname',
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nicknameCtrl,
                maxLength: nicknameMaxLength,
                decoration: const InputDecoration(
                  counterText: '',
                  isDense: true,
                  // 收紧内边距降低高度（与表单数字输入同口径）
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  hintText: 'Enter a nickname',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppPrimaryButton(
            text: 'Save',
            onTap: _isSaving ? null : _saveNickname,
          ),
        ],
      ),
    );
  }
}
