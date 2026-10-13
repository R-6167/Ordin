import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/diagnostic_service.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  List<Map<String, Object?>> _events = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final events = await DiagnosticService.instance.recent(limit: 200);
    if (!mounted) return;
    setState(() {
      _events = events;
      _loading = false;
    });
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final report = await DiagnosticService.instance.exportJson(limit: 500);
      await Share.share(report, subject: 'Ordin diagnostic report');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not prepare diagnostics export')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear diagnostics?'),
        content: const Text('This deletes local diagnostic events only. It does not affect your personal data or analytics.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    await DiagnosticService.instance.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Diagnostics'),
          actions: [
            IconButton(
              tooltip: 'Export diagnostic report',
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.ios_share),
            ),
            IconButton(
              tooltip: 'Clear diagnostics',
              onPressed: _clear,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Local diagnostic trace',
                        style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      'Development builds capture lifecycle and refresh timing. Release builds retain only error-level events. Reports exclude analytics and include only allow-listed operational details.',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.72), fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Text('${_events.length} recent event${_events.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: AppTheme.silver)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _export,
                        icon: const Icon(Icons.ios_share),
                        label: Text(_busy ? 'Preparing…' : 'Export diagnostic report'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppTheme.amber),
                ))
              else if (_events.isEmpty)
                const GlassCard(child: Text('No diagnostic events recorded yet.'))
              else
                ..._events.map((event) {
                  final name = event['event_name']?.toString() ?? 'event';
                  final category = event['category']?.toString() ?? 'app';
                  final severity = event['severity']?.toString() ?? 'info';
                  final timestamp = event['occurred_at'];
                  final date = timestamp is int
                      ? DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal().toString()
                      : 'Unknown time';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            severity == 'error' || severity == 'fatal'
                                ? Icons.error_outline
                                : Icons.timeline,
                            color: severity == 'error' || severity == 'fatal'
                                ? Colors.redAccent
                                : AppTheme.seed,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
                                Text('$category · $severity',
                                    style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.65), fontSize: 12)),
                                Text(date,
                                    style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
