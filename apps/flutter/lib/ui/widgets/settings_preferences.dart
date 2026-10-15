import 'package:flutter/material.dart';

import '../theme.dart';
import 'glass.dart';

/// Currency + week-start preferences (extracted for maintainable settings).
class SettingsPreferencesCard extends StatelessWidget {
  const SettingsPreferencesCard({
    super.key,
    required this.currency,
    required this.weekStart,
    required this.onCurrency,
    required this.onWeekStart,
  });

  final String currency;
  final int weekStart;
  final Future<void> Function(String currency) onCurrency;
  final Future<void> Function(int weekStart) onWeekStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preferences', style: Theme.of(context).textTheme.titleMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Currency', style: TextStyle(color: AppTheme.silver)),
              subtitle: Text(currency, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5))),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
              onTap: () async {
                final next = await showDialog<String>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: const Text('Currency'),
                    children: [
                      for (final c in [
                        'KES', 'USD', 'EUR', 'GBP', 'UGX', 'TZS',
                        'NGN', 'GHS', 'ZAR', 'INR', 'CAD', 'AUD',
                      ])
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx, c),
                          child: Text(c),
                        ),
                    ],
                  ),
                );
                if (next != null) await onCurrency(next);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Week starts on', style: TextStyle(color: AppTheme.silver)),
              subtitle: Text(
                weekStart == 0 ? 'Sunday' : 'Monday',
                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5)),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
              onTap: () async {
                final next = await showDialog<int>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: const Text('Week starts on'),
                    children: [
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(ctx, 0),
                        child: const Text('Sunday'),
                      ),
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(ctx, 1),
                        child: const Text('Monday'),
                      ),
                    ],
                  ),
                );
                if (next != null) await onWeekStart(next);
              },
            ),
          ],
        ),
      ),
    );
  }
}
