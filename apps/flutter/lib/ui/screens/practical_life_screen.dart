import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Documents, vehicle service, maintenance, warranties, shopping, appointments.
class PracticalLifeScreen extends StatefulWidget {
  const PracticalLifeScreen({super.key});

  @override
  State<PracticalLifeScreen> createState() => _PracticalLifeScreenState();
}

class _PracticalLifeScreenState extends State<PracticalLifeScreen> {
  final _ext = ExtendedRepository(AppDatabase.instance);
  List<Map<String, Object?>> _docs = [];
  List<Map<String, Object?>> _practical = [];
  List<Map<String, Object?>> _appointments = [];
  List<Map<String, Object?>> _shopping = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final docs = await _ext.listDocuments();
      final practical = await _ext.listPractical();
      final appointments = await _ext.listUpcomingAppointments(days: 30);
      final shopping = await _ext.listShoppingLists();
      if (!mounted) return;
      setState(() {
        _docs = docs;
        _practical = practical;
        _appointments = appointments;
        _shopping = shopping;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load practical-life items.'; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Practical life failed to load: $e')),
      );
    }
  }

  String _fmtDue(Object? ms) {
    if (ms is! int) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _addDoc() async {
    final title = TextEditingController();
    DateTime? expires;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                style: const TextStyle(color: AppTheme.silver),
                decoration:
                    const InputDecoration(labelText: 'Title (e.g. Driving licence)'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  expires == null
                      ? 'Expiry date (optional)'
                      : 'Expires ${_fmtDue(expires!.millisecondsSinceEpoch)}',
                  style: const TextStyle(color: AppTheme.silver, fontSize: 14),
                ),
                trailing: const Icon(Icons.event, color: AppTheme.amber),
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: expires ?? DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (p != null) setLocal(() => expires = p);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, title.text.trim().isNotEmpty),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _ext.addDocument(title.text.trim(), expiresAt: expires);
    await _load();
  }

  Future<void> _addPractical() async {
    final title = TextEditingController();
    var kind = 'HOUSEHOLD';
    DateTime? due;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Practical item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              DropdownButtonFormField<String>(
                value: kind,
                dropdownColor: AppTheme.metal,
                decoration: const InputDecoration(labelText: 'Kind'),
                items: const [
                  DropdownMenuItem(value: 'HOUSEHOLD', child: Text('Household')),
                  DropdownMenuItem(value: 'VEHICLE', child: Text('Vehicle / service')),
                  DropdownMenuItem(value: 'MAINTENANCE', child: Text('Maintenance')),
                  DropdownMenuItem(value: 'WARRANTY', child: Text('Warranty')),
                  DropdownMenuItem(value: 'RENEWAL', child: Text('Renewal')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) => setLocal(() => kind = v ?? kind),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  due == null
                      ? 'Due date (optional)'
                      : 'Due ${_fmtDue(due!.millisecondsSinceEpoch)}',
                  style: const TextStyle(color: AppTheme.silver, fontSize: 14),
                ),
                trailing: const Icon(Icons.event, color: AppTheme.amber),
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: due ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (p != null) setLocal(() => due = p);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, title.text.trim().isNotEmpty),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _ext.addPractical(title.text.trim(), type: kind, dueAt: due);
    await _load();
  }

  Future<void> _addShopping() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Shopping list'),
        content: TextField(
          controller: name,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(labelText: 'List name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, name.text.trim().isNotEmpty),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _ext.addShoppingList(name.text.trim());
    await _load();
  }

  Widget _overviewChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: AppTheme.amber),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AppTheme.silver, fontSize: 12)),
        ]),
      );

  Widget _section(String title, VoidCallback onAdd, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
              ),
              TextButton(onPressed: onAdd, child: const Text('Add')),
            ],
          ),
        ),
        if (children.isEmpty)
          Text('None yet',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ...children,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Practical life'),
          actions: [
            IconButton(
              tooltip: 'Refresh practical-life items',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, color: AppTheme.amber, size: 36),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.silver)),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Life admin overview',
                            style: TextStyle(color: AppTheme.silver, fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _overviewChip(Icons.description_outlined, '${_docs.length} documents'),
                            _overviewChip(Icons.build_outlined, '${_practical.length} items to track'),
                            _overviewChip(Icons.event_outlined, '${_appointments.length} upcoming'),
                            _overviewChip(Icons.shopping_basket_outlined, '${_shopping.length} lists'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Documents, vehicle, maintenance, warranties, shopping — all feed Needs Attention when due.',
                    style: TextStyle(
                        color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
                  ),
                  _section(
                    'Documents',
                    _addDoc,
                    _docs
                        .map((d) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GlassCard(
                                child: ListTile(
                                  title: Text('${d['title']}',
                                      style: const TextStyle(color: AppTheme.silver)),
                                  subtitle: d['expires_at'] != null
                                      ? Text('Expires ${_fmtDue(d['expires_at'])}',
                                          style: TextStyle(
                                              color: AppTheme.silver.withValues(alpha: 0.45),
                                              fontSize: 12))
                                      : null,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  _section(
                    'Practical / vehicle / warranty',
                    _addPractical,
                    _practical
                        .map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GlassCard(
                                child: ListTile(
                                  title: Text('${p['title']}',
                                      style: const TextStyle(color: AppTheme.silver)),
                                  subtitle: Text(
                                    [
                                      if (p['kind'] != null) '${p['kind']}',
                                      if (p['due_at'] != null) 'due ${_fmtDue(p['due_at'])}',
                                    ].join(' · '),
                                    style: TextStyle(
                                        color: AppTheme.silver.withValues(alpha: 0.45),
                                        fontSize: 12),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.check, color: AppTheme.amber),
                                    onPressed: () async {
                                      await _ext.completePractical(p['id'] as String);
                                      await _load();
                                    },
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  _section(
                    'Appointments (next 30 days)',
                    () {},
                    _appointments
                        .map((a) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GlassCard(
                                child: ListTile(
                                  title: Text('${a['title']}',
                                      style: const TextStyle(color: AppTheme.silver)),
                                  subtitle: a['start_at'] != null
                                      ? Text(_fmtDue(a['start_at']),
                                          style: TextStyle(
                                              color: AppTheme.silver.withValues(alpha: 0.45),
                                              fontSize: 12))
                                      : null,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  _section(
                    'Shopping lists',
                    _addShopping,
                    _shopping
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GlassCard(
                                child: ListTile(
                                  title: Text('${s['name']}',
                                      style: const TextStyle(color: AppTheme.silver)),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
      ),
    );
  }
}
