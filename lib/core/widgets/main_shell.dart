import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ev_tool_app/core/widgets/app_bottom_nav.dart';

/// Hosts the StatefulShellRoute: renders the active branch underneath a
/// bottom navigation bar. Re-tapping the current tab resets the branch
/// to its initial location.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        shell,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AppBottomNav(
            currentIndex: shell.currentIndex,
            onTap: (index) {
              shell.goBranch(
                index,
                initialLocation: index == shell.currentIndex,
              );
            },
          ),
        ),
      ],
    );
  }
}
