import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';

/// Displays a standard warning and confirmation dialog before performing delete operations.
Future<bool?> showConfirmDeleteDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Ya, Hapus',
  String cancelText = 'Batal',
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final tt = Theme.of(ctx).textTheme;
      final sem = ctx.semantic;

      return AlertDialog(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: sem.dangerBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(LucideIcons.alertTriangle, color: sem.danger, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: tt.headlineSmall?.copyWith(fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: tt.bodyMedium?.copyWith(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              cancelText,
              style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      );
    },
  );
}
