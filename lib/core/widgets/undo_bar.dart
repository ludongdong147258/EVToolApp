import 'dart:async';

import 'package:flutter/material.dart';

/// 撤销提示条（移植小程序 UndoBar）：删除后 5 秒内可撤销。
///
/// Scaffold 的 floating bottomNavigationBar 之下自动避让。
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showUndoBar(
  BuildContext context, {
  required String text,
  required VoidCallback onUndo,
  String actionText = '撤销',
  Duration duration = const Duration(seconds: 5),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      duration: duration,
      action: SnackBarAction(label: actionText, onPressed: onUndo),
    ),
  );
}

/// 5 秒撤销窗口的通用控制器：先执行 [remove]（乐观删除），
/// 到期后执行 [commit]；期间撤销则执行 [restore] 并取消提交。
class UndoController {
  UndoController({
    required this.remove,
    required this.restore,
    required this.commit,
    this.window = const Duration(seconds: 5),
  });

  final VoidCallback remove;
  final VoidCallback restore;
  final VoidCallback commit;
  final Duration window;

  Timer? _timer;

  bool get isPending => _timer != null;

  /// 开始一个撤销窗口。
  void start() {
    _timer?.cancel();
    remove();
    _timer = Timer(window, () {
      _timer = null;
      commit();
    });
  }

  /// 用户点击撤销。
  void undo() {
    _timer?.cancel();
    _timer = null;
    restore();
  }

  /// 立即提交（例如用户又删除了下一条）。
  void forceCommit() {
    _timer?.cancel();
    _timer = null;
    commit();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
