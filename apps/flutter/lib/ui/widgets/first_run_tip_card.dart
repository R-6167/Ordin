import 'package:flutter/material.dart';

import '../../services/first_run_tip.dart';
import '../theme.dart';
import 'glass.dart';

/// Dismissible one-time tip shown on Today until the user acknowledges it.
class FirstRunTipCard extends StatefulWidget {
  const FirstRunTipCard({super.key, this.tip});

  final FirstRunTip? tip;

  @override
  State<FirstRunTipCard> createState() => _FirstRunTipCardState();
}

class _FirstRunTipCardState extends State<FirstRunTipCard> {
  late final FirstRunTip _tip;
  bool _ready = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _tip = widget.tip ?? FirstRunTip.instance;
    _load();
  }

  Future<void> _load() async {
    if (!_tip.isLoaded) await _tip.load();
    if (!mounted) return;
    setState(() {
      _ready = true;
      _visible = _tip.shouldShow;
    });
  }

  Future<void> _dismiss() async {
    await _tip.dismiss();
    if (!mounted) return;
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || !_visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.brandBlueContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lightbulb_outline, color: AppTheme.brandBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to Ordin',
                    style: TextStyle(
                      color: AppTheme.silver,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Everything stays on this device. Start from Today, explore Life for goals and Finance, and use Timeline for your history.',
                    style: TextStyle(
                      color: AppTheme.silver.withValues(alpha: 0.62),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: _dismiss,
              icon: Icon(Icons.close, size: 18, color: AppTheme.silver.withValues(alpha: 0.55)),
            ),
          ],
        ),
      ),
    );
  }
}
