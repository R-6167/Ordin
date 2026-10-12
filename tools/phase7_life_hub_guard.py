"""Phase 7: generation-gated LifeHub navigation."""
from pathlib import Path
import subprocess
import sys


def main_content(path: str) -> str:
    for ref in ('origin/main', 'main'):
        try:
            return subprocess.check_output(['git', 'show', f'{ref}:{path}'], text=True)
        except subprocess.CalledProcessError:
            continue
    subprocess.check_call(['git', 'fetch', 'origin', 'main', '--depth=1'])
    return subprocess.check_output(['git', 'show', f'origin/main:{path}'], text=True)


def main() -> None:
    path = 'apps/flutter/lib/ui/hubs/life_hub.dart'
    t = main_content(path)
    if 'Future<void> _open(Widget page' in t:
        print('already patched')
        return
    if "import '../../services/app_data_bus.dart';" not in t:
        t = t.replace(
            "import '../../data/database.dart';\n",
            "import '../../data/database.dart';\nimport '../../services/app_data_bus.dart';\n",
            1,
        )
    helper = '''
  /// Push a screen; only bubble [onChanged] if data actually mutated.
  Future<void> _open(Widget page, {bool reloadPractical = false}) async {
    final gen = AppDataBus.instance.generation;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    if (reloadPractical) await _loadPractical();
    if (AppDataBus.instance.generation != gen) {
      await widget.onChanged();
    }
  }

'''
    end = t.find('\n  List<String> get _attention')
    if end < 0:
        end = t.find('\n  Widget _navCard')
    if end < 0:
        sys.exit('insert point missing')
    t = t[:end] + '\n' + helper + t[end:]

    reps = [
        (
            '''          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const NeedsAttentionScreen()))
                .then((_) => widget.onChanged());
          },''',
            '''          onTap: () => _open(const NeedsAttentionScreen()),''',
        ),
        (
            '''          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PracticalLifeScreen()))
                .then((_) {
              _loadPractical();
              return widget.onChanged();
            });
          },''',
            '''          onTap: () => _open(const PracticalLifeScreen(), reloadPractical: true),''',
        ),
        (
            '''                  onTap: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: g.id)))
                        .then((_) => widget.onChanged());
                  },''',
            '''                  onTap: () => _open(GoalDetailScreen(goalId: g.id)),''',
        ),
        (
            '''                  onTap: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: p.id)))
                        .then((_) => widget.onChanged());
                  },''',
            '''                  onTap: () => _open(ProjectDetailScreen(projectId: p.id)),''',
        ),
        (
            '''                  onTap: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: h.id)))
                        .then((_) => widget.onChanged());
                  },''',
            '''                  onTap: () => _open(HabitDetailScreen(habitId: h.id)),''',
        ),
        (
            '''                  onTap: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => RoutineDetailScreen(routineId: r.id)))
                        .then((_) => widget.onChanged());
                  },''',
            '''                  onTap: () => _open(RoutineDetailScreen(routineId: r.id)),''',
        ),
        (
            '''                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => NoteDetailScreen(noteId: n.id)),
                    );
                  },''',
            '''                  onTap: () => _open(NoteDetailScreen(noteId: n.id)),''',
        ),
        (
            '''          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LifeAreasScreen()),
            );
          },''',
            '''          onTap: () => _open(const LifeAreasScreen()),''',
        ),
        (
            '''          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WellnessScreen()));
          },''',
            '''          onTap: () => _open(const WellnessScreen()),''',
        ),
        (
            '''          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScheduleScreen()));
          },''',
            '''          onTap: () => _open(const ScheduleScreen()),''',
        ),
        (
            '''          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanningScreen()));
          },''',
            '''          onTap: () => _open(const PlanningScreen()),''',
        ),
        (
            '''          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
          },''',
            '''          onTap: () => _open(const CalendarScreen()),''',
        ),
    ]
    for old, new in reps:
        if old not in t:
            sys.exit(f'marker missing: {old[:70]!r}')
        t = t.replace(old, new, 1)
    if '.then((_) => widget.onChanged())' in t:
        sys.exit('still has unguarded then onChanged')
    Path(path).write_text(t)
    print('patched', len(t))


if __name__ == '__main__':
    main()
