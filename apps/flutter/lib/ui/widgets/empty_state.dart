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
    // Fixed scale so system font size cannot turn this into a full-screen banner.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(1.0),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppTheme.brandBlue.withValues(alpha: 0.55)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.silver,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                height: 1.25,
              ),
            ),
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.silver.withValues(alpha: 0.65),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
