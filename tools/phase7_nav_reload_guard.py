"""Phase 7: generation-gated Schedule reloads + note field preserve."""
from pathlib import Path
import subprocess
import sys


def _show(ref: str, path: str) -> str:
    return subprocess.check_output(['git', 'show', f'{ref}:{path}'], text=True)


def _main_file(path: str) -> str:
    for ref in ('origin/main', 'main'):
        try:
            return _show(ref, path)
        except subprocess.CalledProcessError:
            continue
    subprocess.check_call(['git', 'fetch', 'origin', 'main', '--depth=1'])
    return _show('origin/main', path)


def patch_schedule() -> None:
    p = Path('apps/flutter/lib/ui/screens/schedule_screen.dart')
    s = _main_file('apps/flutter/lib/ui/screens/schedule_screen.dart')
    if "import '../../services/app_data_bus.dart';" not in s:
        s = s.replace(
            "import '../../services/build_my_day.dart';",
            "import '../../services/app_data_bus.dart';\nimport '../../services/build_my_day.dart';",
            1,
        )
    old_plan = (
        '                                  onPressed: () {\n'
        '                                    Navigator.of(context)\n'
        '                                        .push(\n'
        '                                      MaterialPageRoute(\n'
        '                                        builder: (_) =>\n'
        '                                            PlanningScreen(initialDay: _day),\n'
        '                                      ),\n'
        '                                    )\n'
        '                                        .then((_) => _load());\n'
        '                                  },'
    )
    new_plan = (
        '                                  onPressed: () async {\n'
        '                                    final gen = AppDataBus.instance.generation;\n'
        '                                    await Navigator.of(context).push(\n'
        '                                      MaterialPageRoute(\n'
        '                                        builder: (_) =>\n'
        '                                            PlanningScreen(initialDay: _day),\n'
        '                                      ),\n'
        '                                    );\n'
        '                                    if (!mounted) return;\n'
        '                                    if (AppDataBus.instance.generation != gen) {\n'
        '                                      await _load();\n'
        '                                    }\n'
        '                                  },'
    )
    if old_plan not in s:
        if 'AppDataBus.instance.generation' in s:
            print('schedule plan nav already gated')
        else:
            sys.exit('schedule plan marker missing')
    else:
        s = s.replace(old_plan, new_plan, 1)
    old_task = (
        '                        onTap: s.kind == DaySlotKind.task && s.entityId != null\n'
        '                            ? () => Navigator.of(context).push(\n'
        '                                  MaterialPageRoute(\n'
        '                                    builder: (_) =>\n'
        '                                        TaskDetailScreen(taskId: s.entityId!),\n'
        '                                  ),\n'
        '                                )\n'
        '                            : null,'
    )
    new_task = (
        '                        onTap: s.kind == DaySlotKind.task && s.entityId != null\n'
        '                            ? () async {\n'
        '                                final gen = AppDataBus.instance.generation;\n'
        '                                await Navigator.of(context).push(\n'
        '                                  MaterialPageRoute(\n'
        '                                    builder: (_) =>\n'
        '                                        TaskDetailScreen(taskId: s.entityId!),\n'
        '                                  ),\n'
        '                                );\n'
        '                                if (!mounted) return;\n'
        '                                if (AppDataBus.instance.generation != gen) {\n'
        '                                  await _load();\n'
        '                                }\n'
        '                              }\n'
        '                            : null,'
    )
    if old_task not in s:
        if 'TaskDetailScreen(taskId: s.entityId!)' in s and 'AppDataBus.instance.generation' in s:
            print('schedule task nav already gated')
        else:
            sys.exit('schedule task marker missing')
    else:
        s = s.replace(old_task, new_task, 1)
    p.write_text(s)
    print('schedule ok', len(s))


def patch_note() -> None:
    p = Path('apps/flutter/lib/ui/screens/note_detail_screen.dart')
    n = p.read_text()
    if 'Only overwrite fields when text differs' in n:
        print('note already patched')
        return
    # Prefer main if note was not yet patched on branch
    if 'Only overwrite' not in n:
        try:
            n = _main_file('apps/flutter/lib/ui/screens/note_detail_screen.dart')
        except Exception:
            pass
    old_set = (
        '    setState(() {\n'
        '      _note = n;\n'
        '      _links\n'
        '        ..clear()\n'
        '        ..addAll(resolved);\n'
        '      if (n != null) {\n'
        '        _content.text = n.content;\n'
        "        _title.text = n.title ?? '';\n"
        '      }\n'
        '      _loading = false;\n'
        '    });'
    )
    new_set = (
        '    setState(() {\n'
        '      _note = n;\n'
        '      _links\n'
        '        ..clear()\n'
        '        ..addAll(resolved);\n'
        '      // Only overwrite fields when text differs — preserves cursor/focus while typing.\n'
        '      if (n != null) {\n'
        '        final nextContent = n.content;\n'
        "        final nextTitle = n.title ?? '';\n"
        '        if (_content.text != nextContent) _content.text = nextContent;\n'
        '        if (_title.text != nextTitle) _title.text = nextTitle;\n'
        '      }\n'
        '      _loading = false;\n'
        '    });'
    )
    if old_set not in n:
        sys.exit('note patch failed — marker missing')
    n = n.replace(old_set, new_set, 1)
    p.write_text(n)
    print('note ok', len(n))


def main() -> None:
    patch_schedule()
    patch_note()


if __name__ == '__main__':
    main()
