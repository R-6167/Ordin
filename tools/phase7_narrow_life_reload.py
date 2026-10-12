"""Phase 7: only load life lists when DataDomain.life is dirty."""
from pathlib import Path
import sys


def main() -> None:
    p = Path('apps/flutter/lib/ui/home_shell.dart')
    t = p.read_text()
    if 'Phase7: life lists only when wantLife' in t:
        print('already patched')
        return
    old = (
        '    if (wantLife || wantToday) {\n'
        '      futures.add(() async {\n'
        '        habitList =\n'
        "            await softFuture(_habits.listActive, fallback: <Habit>[], label: 'habits') ??\n"
        '                <Habit>[];\n'
        '        if (wantLife) {\n'
        '          goalList =\n'
        "              await softFuture(_goals.listActive, fallback: <Goal>[], label: 'goals') ??\n"
        '                  <Goal>[];\n'
        '          noteList =\n'
        "              await softFuture(_notes.list, fallback: <Note>[], label: 'notes') ?? <Note>[];\n"
        '          projectList =\n'
        "              await softFuture(_projects.listActive, fallback: <Project>[], label: 'projects') ??\n"
        '                  <Project>[];\n'
        '          routineList =\n'
        "              await softFuture(_routines.listActive, fallback: <Routine>[], label: 'routines') ??\n"
        '                  <Routine>[];\n'
        '        }\n'
        '      }());\n'
        '    }'
    )
    new = (
        '    // Phase7: life lists only when wantLife — Today does not need habits/goals.\n'
        '    if (wantLife) {\n'
        '      futures.add(() async {\n'
        '        habitList =\n'
        "            await softFuture(_habits.listActive, fallback: <Habit>[], label: 'habits') ??\n"
        '                <Habit>[];\n'
        '        goalList =\n'
        "            await softFuture(_goals.listActive, fallback: <Goal>[], label: 'goals') ??\n"
        '                <Goal>[];\n'
        '        noteList =\n'
        "            await softFuture(_notes.list, fallback: <Note>[], label: 'notes') ?? <Note>[];\n"
        '        projectList =\n'
        "            await softFuture(_projects.listActive, fallback: <Project>[], label: 'projects') ??\n"
        '                <Project>[];\n'
        '        routineList =\n'
        "            await softFuture(_routines.listActive, fallback: <Routine>[], label: 'routines') ??\n"
        '                <Routine>[];\n'
        '      }());\n'
        '    }'
    )
    if old not in t:
        sys.exit('reload life block marker missing')
    t = t.replace(old, new, 1)
    p.write_text(t)
    print('patched', len(t))


if __name__ == '__main__':
    main()
