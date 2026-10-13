"""W3: open full note editor on Add; multiline TextField."""
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


def patch_forms() -> None:
    path = 'apps/flutter/lib/ui/forms/create_forms.dart'
    t = show(path)
    if '_openNewNoteEditor' in t:
        print('forms already')
        return
    if "import '../screens/note_detail_screen.dart';" not in t:
        t = t.replace(
            "import '../theme.dart';\n",
            "import '../theme.dart';\nimport '../screens/note_detail_screen.dart';\n",
            1,
        )
    old = (
        '    case AddKind.note:\n'
        '      return _simpleText(\n'
        "        context,\n"
        "        title: 'New note',\n"
        "        fields: const ['Content'],\n"
        '        onSave: (v) async {\n'
        '          await NoteRepository(AppDatabase.instance).create(content: v[0]);\n'
        '        },\n'
        '      );'
    )
    new = (
        '    case AddKind.note:\n'
        '      // Full note editor (multiline + links + turn-to-tasks), not a one-line dialog.\n'
        '      return _openNewNoteEditor(context);'
    )
    if old not in t:
        sys.exit('forms note case missing')
    t = t.replace(old, new, 1)
    helper = (
        '\nFuture<bool> _openNewNoteEditor(BuildContext context) async {\n'
        "  final note = await NoteRepository(AppDatabase.instance).create(content: '');\n"
        '  if (!context.mounted) return false;\n'
        '  await Navigator.of(context).push(\n'
        '    MaterialPageRoute(builder: (_) => NoteDetailScreen(noteId: note.id)),\n'
        '  );\n'
        '  return true;\n'
        '}\n\n'
    )
    idx = t.find('Future<bool> _taskForm')
    if idx < 0:
        sys.exit('taskForm insert point missing')
    t = t[:idx] + helper + t[idx:]
    Path(path).write_text(t)
    print('forms ok', len(t))


def patch_note() -> None:
    path = 'apps/flutter/lib/ui/screens/note_detail_screen.dart'
    t = show(path)
    if 'TextInputType.multiline' in t:
        print('note already')
        return
    old = (
        '              TextField(\n'
        '                controller: _content,\n'
        '                maxLines: 14,\n'
        '                style: const TextStyle(color: AppTheme.silver, height: 1.45),\n'
        '                decoration: const InputDecoration(\n'
        "                  labelText: 'Note',\n"
        '                  alignLabelWithHint: true,\n'
        "                  hintText: 'Mention Project Alpha, @Amina, electricity bill\u2026',\n"
        '                ),\n'
        '              ),'
    )
    new = (
        '              TextField(\n'
        '                controller: _content,\n'
        '                maxLines: null,\n'
        '                minLines: 8,\n'
        '                keyboardType: TextInputType.multiline,\n'
        '                textInputAction: TextInputAction.newline,\n'
        '                style: const TextStyle(color: AppTheme.silver, height: 1.45),\n'
        '                decoration: const InputDecoration(\n'
        "                  labelText: 'Note',\n"
        '                  alignLabelWithHint: true,\n'
        "                  hintText: 'One idea per line \u00b7 bullets, TODO:, or [ ] for tasks',\n"
        '                ),\n'
        '              ),'
    )
    if old not in t:
        # try ellipsis variants
        if 'maxLines: 14' in t and 'controller: _content' in t:
            import re
            m = re.search(
                r'TextField\(\s*controller: _content,\s*maxLines: 14,[^;]+?\),',
                t,
                re.S,
            )
            if not m:
                sys.exit('note TextField marker missing')
            t = t[: m.start()] + new.strip() + t[m.end() :]
        else:
            sys.exit('note TextField marker missing')
    else:
        t = t.replace(old, new, 1)
    Path(path).write_text(t)
    print('note ok', len(t))


def patch_roadmap() -> None:
    path = 'ROADMAP.md'
    t = show(path)
    t = t.replace(
        '- [ ] FAB `+ Add` uses **domain-scoped** notify (not `allChanged`)',
        '- [x] FAB `+ Add` uses **domain-scoped** notify (not `allChanged`) (#62)',
    )
    t = t.replace(
        '- [ ] Finance **Record expense** refreshes only on successful save',
        '- [x] Finance **Record expense** refreshes only on successful save (#62)',
    )
    t = t.replace(
        '- [ ] Schedule / Day plan: fix **unmodifiable list** (`Cannot add to an unmodifiable list`)',
        '- [x] Schedule / Day plan: fix **unmodifiable list** (`Cannot add to an unmodifiable list`) (#62)',
    )
    t = t.replace(
        '- [ ] Empty day = empty state, not hard failure\n'
        '- [ ] Surface real engine errors cleanly\n'
        '- [ ] Build My Day succeeds on a normal day with open tasks',
        '- [x] Unmodifiable list crash fixed (#62) \u2014 primary load failure\n'
        '- [ ] Empty day = empty state, not hard failure (verify on device)\n'
        '- [ ] Build My Day succeeds on a normal day with open tasks (verify on device)',
    )
    Path(path).write_text(t)
    print('roadmap ok')


def main() -> None:
    patch_forms()
    patch_note()
    patch_roadmap()


if __name__ == '__main__':
    main()
