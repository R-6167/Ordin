import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/health_repository.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  final _repo = HealthRepository(AppDatabase.instance);
  Map<String, Object?>? _today;
  Map<String, Object?> _week = {};
  List<Map<String, Object?>> _recent = [];
  int _mood = 3;
  int _energy = 3;
  int _stress = 3;
  double _sleep = 7;
  bool _loading = true;
  double? _draftWeight;
  double? _draftSteps;
  double? _draftExercise;
  double? _draftWater;
  String? _todayWeight;
  String? _todaySteps;
  String? _todayExercise;
  String? _todayWater;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final today = await _repo.todayCheckin();
      final week = await _repo.weeklySummary();
      final recent = await _repo.recentCheckins();
      if (!mounted) return;
      final tw = await _repo.listMetrics('WEIGHT', limit: 1);
      final ts = await _repo.listMetrics('STEPS', limit: 1);
      final te = await _repo.listMetrics('EXERCISE_MINUTES', limit: 1);
      final twa = await _repo.listMetrics('WATER_ML', limit: 1);
      String? fmt(List<Map<String, Object?>> rows) {
        if (rows.isEmpty) return null;
        final v = rows.first['value'] as num?;
        final u = rows.first['unit'] as String?;
        if (v == null) return null;
        final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
        return (u == null || u.isEmpty) ? s : '$s $u';
      }
      if (!mounted) return;
      setState(() {
        _today = today;
        _week = week;
        _recent = recent;
        if (today != null) {
          _mood = (today['mood'] as int?) ?? 3;
          _energy = (today['energy'] as int?) ?? 3;
          _stress = (today['stress'] as int?) ?? 3;
          _sleep = (today['sleep_hours'] as num?)?.toDouble() ?? 7;
        }
        _todayWeight = fmt(tw);
        _todaySteps = fmt(ts);
        _todayExercise = fmt(te);
        _todayWater = fmt(twa);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wellness data unavailable: $e')),
      );
    }
  }

  Future<void> _saveCheckin() async {
    try {
      await _repo.saveCheckin(
        mood: _mood,
        energy: _energy,
        stress: _stress,
        sleepHours: _sleep,
      );
      if (_draftWeight != null) {
        await _repo.logMetric(type: 'WEIGHT', value: _draftWeight!, unit: 'kg');
      }
      if (_draftSteps != null) {
        await _repo.logMetric(type: 'STEPS', value: _draftSteps!, unit: 'steps');
      }
      if (_draftExercise != null) {
        await _repo.logMetric(type: 'EXERCISE_MINUTES', value: _draftExercise!, unit: 'min');
      }
      if (_draftWater != null) {
        await _repo.logMetric(type: 'WATER_ML', value: _draftWater!, unit: 'ml');
      }
      if (mounted) {
        setState(() {
          _draftWeight = null;
          _draftSteps = null;
          _draftExercise = null;
          _draftWater = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in and metrics saved')),
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _logMetric(String type, String label, String unit) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: Text(label, style: const TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppTheme.silver),
          decoration: InputDecoration(
            labelText: unit,
            helperText: 'Included when you tap Save check-in',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    final v = double.tryParse(c.text.trim());
    if (v == null) return;
    setState(() {
      switch (type) {
        case 'WEIGHT':
          _draftWeight = v;
        case 'STEPS':
          _draftSteps = v;
        case 'EXERCISE_MINUTES':
          _draftExercise = v;
        case 'WATER_ML':
          _draftWater = v;
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label $v $unit queued — tap Save check-in')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Wellness')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Today's check-in",
                            style: TextStyle(
                                color: AppTheme.silver,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        const SizedBox(height: 12),
                        _slider('Mood', _mood, (v) => setState(() => _mood = v)),
                        _slider('Energy', _energy, (v) => setState(() => _energy = v)),
                        _slider('Stress', _stress, (v) => setState(() => _stress = v)),
                        Text('Sleep: ${_sleep.toStringAsFixed(1)} h',
                            style: const TextStyle(color: AppTheme.silver)),
                        Slider(
                          value: _sleep.clamp(0, 14),
                          min: 0,
                          max: 14,
                          divisions: 28,
                          activeColor: AppTheme.amber,
                          onChanged: (v) => setState(() => _sleep = v),
                        ),
                        FilledButton(onPressed: _saveCheckin, child: const Text('Save check-in & metrics')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('This week',
                            style: TextStyle(
                                color: AppTheme.silver, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                          'Avg mood ${_fmt(_week['avg_mood'])} · energy ${_fmt(_week['avg_energy'])} · sleep ${_fmt(_week['avg_sleep'])}h',
                          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Quick metrics',
                      style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => _logMetric('WEIGHT', 'Weight', 'kg'),
                        child: const Text('Weight'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _logMetric('STEPS', 'Steps', 'steps'),
                        child: const Text('Steps'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _logMetric('EXERCISE_MINUTES', 'Exercise', 'min'),
                        child: const Text('Exercise'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _logMetric('WATER_ML', 'Water', 'ml'),
                        child: const Text('Water'),
                      ),
                    ],
                  ),
                  if (_draftWeight != null ||
                      _draftSteps != null ||
                      _draftExercise != null ||
                      _draftWater != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Queued: ${[
                          if (_draftWeight != null) 'Weight $_draftWeight kg',
                          if (_draftSteps != null) 'Steps $_draftSteps',
                          if (_draftExercise != null) 'Exercise $_draftExercise min',
                          if (_draftWater != null) 'Water $_draftWater ml',
                        ].join(' · ')}',
                        style: TextStyle(color: AppTheme.amber.withValues(alpha: 0.9), fontSize: 12),
                      ),
                    ),
                  if (_todayWeight != null ||
                      _todaySteps != null ||
                      _todayExercise != null ||
                      _todayWater != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Latest saved: ${[
                          if (_todayWeight != null) 'Weight $_todayWeight',
                          if (_todaySteps != null) 'Steps $_todaySteps',
                          if (_todayExercise != null) 'Exercise $_todayExercise',
                          if (_todayWater != null) 'Water $_todayWater',
                        ].join(' · ')}',
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text('Recent check-ins',
                      style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  if (_recent.isEmpty)
                    Text('No history yet',
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)))
                  else
                    ..._recent.map((c) {
                      final d = DateTime.fromMillisecondsSinceEpoch(c['day'] as int);
                      return ListTile(
                        dense: true,
                        title: Text(
                          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: AppTheme.silver),
                        ),
                        subtitle: Text(
                          'Mood ${c['mood'] ?? '—'} · Energy ${c['energy'] ?? '—'} · Sleep ${c['sleep_hours'] ?? '—'}h',
                          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }

  Widget _slider(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value / 5', style: const TextStyle(color: AppTheme.silver)),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: AppTheme.amber,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }

  String _fmt(Object? v) {
    if (v == null) return '—';
    if (v is num) return v.toStringAsFixed(1);
    return '$v';
  }
}
