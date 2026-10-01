import 'package:flutter/material.dart';

/// Shows a centered success toast that auto-dismisses after 2 seconds.
void showSuccessToast(
  BuildContext context, {
  String message = 'Submitted successfully',
}) {
  showDialog(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    useRootNavigator: true,
    builder: (dialogContext) {
      Future.delayed(const Duration(seconds: 2), () {
        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      });
      return Material(
        type: MaterialType.transparency,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Shows a centered error toast that auto-dismisses after 2 seconds.
void showErrorToast(BuildContext context, String message) {
  showDialog(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    useRootNavigator: true,
    builder: (dialogContext) {
      Future.delayed(const Duration(seconds: 2), () {
        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      });
      return Material(
        type: MaterialType.transparency,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
