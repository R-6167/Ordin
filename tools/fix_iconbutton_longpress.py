"""Flutter 3.27 IconButton has no onLongPress — use PopupMenu."""
from pathlib import Path
import subprocess
import sys


def main() -> None:
    path = 'apps/flutter/lib/ui/screens/project_detail_screen.dart'
    t = Path(path).read_text()
    old = (
        "                            IconButton(\n"
        "                              tooltip: 'Due date',\n"
        "                              icon: const Icon(Icons.event_outlined, color: AppTheme.silverMuted, size: 18),\n"
        "                              onPressed: () => _setMilestoneDue(m),\n"
        "                              onLongPress: () => _clearMilestoneDue(m),\n"
        "                            ),"
    )
    new = (
        "                            PopupMenuButton<String>(\n"
        "                              tooltip: 'Due date',\n"
        "                              icon: const Icon(Icons.event_outlined,\n"
        "                                  color: AppTheme.silverMuted, size: 18),\n"
        "                              color: AppTheme.metalDeep,\n"
        "                              onSelected: (v) async {\n"
        "                                if (v == 'set') await _setMilestoneDue(m);\n"
        "                                if (v == 'clear') await _clearMilestoneDue(m);\n"
        "                              },\n"
        "                              itemBuilder: (_) => [\n"
        "                                const PopupMenuItem(\n"
        "                                  value: 'set',\n"
        "                                  child: Text('Set due date'),\n"
        "                                ),\n"
        "                                if (m['due_at'] != null)\n"
        "                                  const PopupMenuItem(\n"
        "                                    value: 'clear',\n"
        "                                    child: Text('Clear due date'),\n"
        "                                  ),\n"
        "                              ],\n"
        "                            ),"
    )
    if old not in t:
        if 'onLongPress: () => _clearMilestoneDue' not in t:
            print('already fixed')
            return
        sys.exit('marker missing')
    Path(path).write_text(t.replace(old, new, 1))
    print('fixed')


if __name__ == '__main__':
    main()
