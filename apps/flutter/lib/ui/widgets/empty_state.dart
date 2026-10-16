import 'package:flutter/material.dart';

import '../theme.dart';

/// Consistent empty-list / empty-hub placeholder.
///
/// Prefer this over one-off grey text so empty screens stay readable under
/// large system text and share the same hierarchy as the rest of the app.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.detail,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
  });

  final String title;
  final String? detail;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Explicit sizes so accessibility scale cannot turn this into a banner.
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppTheme.silver.withValues(alpha: 0.32)),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.silver.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
              fontSize: 15,
              height: 1.25,
            ),
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.silver.withValues(alpha: 0.45),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
