import 'package:flutter/material.dart';

import '../../domain/archive_cascade.dart';
import '../theme.dart';

/// Result of [showArchiveSheet], or null if cancelled.
class ArchiveSheetResult {
  const ArchiveSheetResult(this.cascade);
  final ArchiveCascade cascade;
}

/// Confirm archive with explicit cascade choice.
Future<ArchiveSheetResult?> showArchiveSheet({
  required BuildContext context,
  required String title,
  required Map<String, int> impact,
  required List<({ArchiveCascade mode, String label, String subtitle})> options,
  ArchiveCascade initial = ArchiveCascade.parentOnly,
}) async {
  var selected = initial;
  return showModalBottomSheet<ArchiveSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final chips = impact.entries
              .where((e) => e.value > 0)
              .map((e) => '${e.value} ${e.key}')
              .join(' · ');
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    chips,
                    style: TextStyle(
                      color: AppTheme.silver.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                for (final o in options)
                  RadioListTile<ArchiveCascade>(
                    value: o.mode,
                    groupValue: selected,
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() => selected = v);
                    },
                    title: Text(o.label),
                    subtitle: Text(o.subtitle, style: const TextStyle(fontSize: 12)),
                    activeColor: AppTheme.amber,
                    contentPadding: EdgeInsets.zero,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pop(ctx, ArchiveSheetResult(selected)),
                      child: const Text('Archive'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
