import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/app_bottom_nav.dart';

/// StatefulShellRoute 宿主：分支内容铺底 + 浮动胶囊底栏覆盖其上。
///
/// 内容底部预留滚动余量，由各 tab 页在自己的 ScrollView padding 中处理
/// （[kBottomNavScrollPadding]）。
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: shell.currentIndex,
        onTap: (index) {
          shell.goBranch(index, initialLocation: index == shell.currentIndex);
        },
      ),
    );
  }
}

/// tab 页 ScrollView 的底部安全 padding（浮动底栏高度 + 上下边距）。
const double kBottomNavScrollPadding =
    AppColors.bottomNavHeight + AppColors.bottomNavOffset * 2;
