"""Phase 7: generation-gated Schedule reloads + note field preserve."""
from pathlib import Path
import sys


def patch_schedule() -> None:
    p = Path('apps/flutter/lib/ui/screens/schedule_screen.dart')
    s = p.read_text()
    if 'AppDataBus.instance.generation' in s and 'Open Day plan' in s:
        # May already be partially patched; ensure both sites
        pass
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
    if old_plan in s:
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
    if old_task in s:
        s = s.replace(old_task, new_task, 1)
    if 'AppDataBus.instance.generation' not in s:
        sys.exit('schedule patch failed — markers missing')
    p.write_text(s)
    print('schedule ok', len(s))


def patch_note() -> None:
    p = Path('apps/flutter/lib/ui/screens/note_detail_screen.dart')
    n = p.read_text()
    if 'Only overwrite fields when text differs' in n:
        print('note already patched')
        return
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
    # Restore schedule from main if our branch simplified it
    import subprocess
    sched = Path('apps/flutter/lib/ui/screens/schedule_screen.dart')
    text = sched.read_text() if sched.exists() else ''
    # Prefer main if branch version looks incomplete
    main_text = subprocess.check_output(
        ['git', 'show', 'origin/main:apps/flutter/lib/ui/screens/schedule_screen.dart'],
        text=True,
        stderr=subprocess.DEVNULL,
    ) if True else text
    try:
        main_text = subprocess.check_output(
            ['git', 'show', 'origin/main:apps/flutter/lib/ui/screens/schedule_screen.dart'],
            text=True,
        )
    except Exception:
        try:
            main_text = subprocess.check_output(
                ['git', 'show', 'main:apps/flutter/lib/ui/screens/schedule_screen.dart'],
                text=True,
            )
        except Exception:
            main_text = text
    if len(main_text) > len(text) + 200:
        sched.write_text(main_text)
        print('restored schedule from main')
    patch_schedule()
    patch_note()


if __name__ == '__main__':
    main()
