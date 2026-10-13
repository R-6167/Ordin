"""Add ValueKey on task/plan GlassCards in HomeShell."""
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


def main() -> None:
    path = 'apps/flutter/lib/ui/home_shell.dart'
    t = show(path)
    if "ValueKey('task-" in t:
        print('already keyed')
    else:
        old = (
            '                  child: GlassCard(\n'
            '                    onTap: () => _openTask(t),'
        )
        new = (
            '                  child: GlassCard(\n'
            "                    key: ValueKey('task-${t.id}'),\n"
            '                    onTap: () => _openTask(t),'
        )
        if old not in t:
            sys.exit('task GlassCard marker missing')
        t = t.replace(old, new)
    old_p = (
        '                  child: GlassCard(\n'
        '                    onTap: () => _openPlanItem(p),'
    )
    new_p = (
        '                  child: GlassCard(\n'
        "                    key: ValueKey('plan-${p.id}'),\n"
        '                    onTap: () => _openPlanItem(p),'
    )
    if old_p in t and "ValueKey('plan-" not in t:
        t = t.replace(old_p, new_p)
    Path(path).write_text(t)
    print('keys', t.count("ValueKey('task-"), t.count("ValueKey('plan-"))

    # ROADMAP
    rp = Path('ROADMAP.md')
    r = show('ROADMAP.md') if not rp.exists() else rp.read_text()
    r = r.replace(
        '- [ ] Stable list keys on Tasks rows (follow-up if flash remains)',
        '- [x] Stable list keys on Tasks / plan rows',
    )
    for a, b in [
        ('- [ ] Life / + Add note opens **note editor** (not single-line popup)',
         '- [x] Life / + Add note opens **note editor** (not single-line popup) (#63)'),
        ('- [ ] Multiline body + Enter creates real lines',
         '- [x] Multiline body + Enter creates real lines (#63)'),
        ('- [ ] Turn lines → tasks respects paragraphs / bullets',
         '- [x] Turn lines → tasks splits on newlines (#63)'),
        ('- [ ] Rename/repurpose More tab as **Timeline**',
         '- [x] Rename/repurpose More tab as **Timeline** (#65)'),
        ('- [ ] Chronological activity (tasks, expenses, notes, habits, …)',
         '- [x] Chronological activity chips (#65)'),
        ('- [ ] AI / intelligence suggestions on the same screen',
         '- [x] Offline suggestions + intelligence link (#65)'),
        ('- [ ] Settings / backup only under Settings (AppBar)',
         '- [x] Settings / backup only under Settings (AppBar) (#65)'),
        ('- [ ] Remove duplicate search field (AppBar search only)',
         '- [x] Remove duplicate search field (AppBar search only) (#65)'),
    ]:
        r = r.replace(a, b)
    r = r.replace(
        '**Last updated:** 2026-10-13 — W4 record expense in progress',
        '**Last updated:** 2026-10-13 — W1–W5 merged; stable list keys',
    )
    Path('ROADMAP.md').write_text(r)
    print('roadmap updated')


if __name__ == '__main__':
    main()
