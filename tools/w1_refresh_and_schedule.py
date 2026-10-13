"""W1: domain-scoped FAB, expense refresh on ok, growable day lists."""
from pathlib import Path
import subprocess
import sys


def show(path: str) -> str:
    for ref in ('origin/main', 'main'):
        try:
            return subprocess.check_output(['git', 'show', f'{ref}:{path}'], text=True)
        except subprocess.CalledProcessError:
            continue
    subprocess.check_call(['git', 'fetch', 'origin', 'main', '--depth=1'])
    return subprocess.check_output(['git', 'show', f'origin/main:{path}'], text=True)


def patch_bmd() -> None:
    path = 'apps/flutter/lib/services/build_my_day.dart'
    t = show(path)
    t = t.replace(
        'if (slots.isEmpty) return const [];',
        'if (slots.isEmpty) return <DaySlot>[];',
        1,
    )
    t = t.replace(
        'if (sorted.isEmpty) return const [];',
        'if (sorted.isEmpty) return <DaySlot>[];',
        1,
    )
    if 'List<DaySlot>.of(mergeOverlappingDaySlots(lockedRaw))' not in t:
        t = t.replace(
            'var locked = mergeOverlappingDaySlots(lockedRaw);',
            'var locked = List<DaySlot>.of(mergeOverlappingDaySlots(lockedRaw));',
            1,
        )
    if 'return <DaySlot>[]' not in t:
        sys.exit('bmd patch failed')
    Path(path).write_text(t)
    print('bmd ok', len(t))


def patch_forms() -> None:
    path = 'apps/flutter/lib/ui/forms/create_forms.dart'
    t = show(path)
    t = t.replace(
        'Future<bool> showUniversalAdd(BuildContext context) async {',
        '/// Returns the created [AddKind] on success, or null if cancelled.\n'
        'Future<AddKind?> showUniversalAdd(BuildContext context) async {',
        1,
    )
    t = t.replace(
        '  if (kind == null || !context.mounted) return false;\n'
        '  return showCreateForm(context, kind);\n'
        '}',
        '  if (kind == null || !context.mounted) return null;\n'
        '  final ok = await showCreateForm(context, kind);\n'
        '  return ok ? kind : null;\n'
        '}',
        1,
    )
    if 'Future<AddKind?>' not in t:
        sys.exit('forms patch failed')
    Path(path).write_text(t)
    print('forms ok', len(t))


def patch_shell() -> None:
    path = 'apps/flutter/lib/ui/home_shell.dart'
    t = show(path)
    old = (
        '  Future<void> _add() async {\n'
        '    final ok = await showUniversalAdd(context);\n'
        '    if (ok) {\n'
        '      HapticFeedback.lightImpact();\n'
        '      AppDataBus.instance.allChanged();\n'
        '    }\n'
        '  }'
    )
    new = (
        '  Future<void> _add() async {\n'
        '    final kind = await showUniversalAdd(context);\n'
        '    if (kind == null) return;\n'
        '    HapticFeedback.lightImpact();\n'
        '    // Domain-scoped notify \u2014 avoid allChanged() full-tab blast.\n'
        '    switch (kind) {\n'
        '      case AddKind.task:\n'
        '      case AddKind.event:\n'
        '      case AddKind.reminder:\n'
        '        AppDataBus.instance.tasksChanged();\n'
        '      case AddKind.expense:\n'
        '      case AddKind.income:\n'
        '      case AddKind.bill:\n'
        '        AppDataBus.instance.financeChanged();\n'
        '      case AddKind.project:\n'
        '      case AddKind.goal:\n'
        '      case AddKind.habit:\n'
        '      case AddKind.routine:\n'
        '      case AddKind.note:\n'
        '      case AddKind.person:\n'
        '        AppDataBus.instance.lifeChanged();\n'
        '    }\n'
        '  }'
    )
    if old not in t:
        if 'Domain-scoped notify' in t:
            print('shell already patched')
            return
        sys.exit('shell _add marker missing')
    Path(path).write_text(t.replace(old, new, 1))
    print('shell ok')


def patch_finance() -> None:
    path = 'apps/flutter/lib/ui/hubs/finance_hub.dart'
    t = show(path)
    old = "onPressed: () => showCreateForm(context, AddKind.expense).then((_) => _refresh()),"
    new = (
        'onPressed: () async {\n'
        '            final ok = await showCreateForm(context, AddKind.expense);\n'
        '            if (ok) await _refresh();\n'
        '          },'
    )
    if old not in t:
        if 'if (ok) await _refresh()' in t:
            print('finance already patched')
            return
        sys.exit('finance marker missing')
    Path(path).write_text(t.replace(old, new))
    print('finance ok')


def main() -> None:
    patch_bmd()
    patch_forms()
    patch_shell()
    patch_finance()


if __name__ == '__main__':
    main()
