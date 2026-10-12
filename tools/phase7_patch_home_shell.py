"""Apply Phase 7 HomeShell debounce + stable tab keys. Run from repo root."""
from pathlib import Path
import subprocess
import sys


def _main_content() -> str:
    for ref in ('origin/main', 'main'):
        try:
            return subprocess.check_output(
                ['git', 'show', f'{ref}:apps/flutter/lib/ui/home_shell.dart'],
                text=True,
                stderr=subprocess.STDOUT,
            )
        except subprocess.CalledProcessError as e:
            last = e
    # Last resort: fetch then retry
    subprocess.check_call(['git', 'fetch', 'origin', 'main', '--depth=1'])
    return subprocess.check_output(
        ['git', 'show', 'origin/main:apps/flutter/lib/ui/home_shell.dart'],
        text=True,
    )


def main() -> None:
    p = Path('apps/flutter/lib/ui/home_shell.dart')
    raw = p.read_text() if p.exists() else ''
    if len(raw) < 1000 or raw.strip() == 'PLACEHOLDER' or '_reload' not in raw:
        print('loading home_shell from main…')
        raw = _main_content()
    t = raw
    if '_scheduleReload' in t and "ValueKey('tab-life')" in t:
        print('already patched')
        return
    old_fields = '  int _busGen = 0;\n'
    new_fields = (
        '  int _busGen = 0;\n'
        '  /// Coalesce rapid AppDataBus events (mutations, pop-navigation).\n'
        '  Set<DataDomain> _pendingDomains = {};\n'
        '  Future<void>? _reloadInFlight;\n'
        '  bool _reloadQueued = false;\n'
        '\n'
    )
    if old_fields not in t:
        sys.exit('fields marker missing')
    t = t.replace(old_fields, new_fields, 1)
    old_onbus = (
        '  void _onBus() {\n'
        '    final gen = AppDataBus.instance.generation;\n'
        '    if (gen == _busGen) return;\n'
        '    _busGen = gen;\n'
        '    final dirty = AppDataBus.instance.takeDirty();\n'
        '    if (dirty.isEmpty) return;\n'
        '    final domains = <DataDomain>{};\n'
        '    domains.addAll(dirty);\n'
        '    _reload(domains: domains);\n'
        '  }\n'
    )
    new_onbus = (
        '  void _onBus() {\n'
        '    final gen = AppDataBus.instance.generation;\n'
        '    if (gen == _busGen) return;\n'
        '    _busGen = gen;\n'
        '    final dirty = AppDataBus.instance.takeDirty();\n'
        '    if (dirty.isEmpty) return;\n'
        '    _pendingDomains.addAll(dirty);\n'
        '    _scheduleReload();\n'
        '  }\n'
        '\n'
        '  /// Debounce + single-flight so bursts of notifyDomains do not thrash UI.\n'
        '  void _scheduleReload() {\n'
        '    if (_reloadQueued) return;\n'
        '    _reloadQueued = true;\n'
        '    Future<void>.delayed(const Duration(milliseconds: 80), () async {\n'
        '      _reloadQueued = false;\n'
        '      if (!mounted) return;\n'
        '      final domains = Set<DataDomain>.from(_pendingDomains);\n'
        '      _pendingDomains.clear();\n'
        '      if (domains.isEmpty) return;\n'
        '      if (_reloadInFlight != null) {\n'
        '        _pendingDomains.addAll(domains);\n'
        '        await _reloadInFlight;\n'
        '        if (!mounted) return;\n'
        '        if (_pendingDomains.isEmpty) return;\n'
        '        final more = Set<DataDomain>.from(_pendingDomains);\n'
        '        _pendingDomains.clear();\n'
        '        _reloadInFlight = _reload(domains: more);\n'
        '        await _reloadInFlight;\n'
        '        _reloadInFlight = null;\n'
        '        return;\n'
        '      }\n'
        '      _reloadInFlight = _reload(domains: domains);\n'
        '      await _reloadInFlight;\n'
        '      _reloadInFlight = null;\n'
        '      if (_pendingDomains.isNotEmpty && mounted) {\n'
        '        _scheduleReload();\n'
        '      }\n'
        '    });\n'
        '  }\n'
    )
    if old_onbus not in t:
        sys.exit('onBus marker missing')
    t = t.replace(old_onbus, new_onbus, 1)
    old_body = (
        '    return IndexedStack(\n'
        '      index: _tab,\n'
        '      children: [\n'
        '        _today(),\n'
        '        _tasksView(),\n'
        '        LifeHub(\n'
        '          goals: _goalList,\n'
        '          habits: _habitList,\n'
        '          notes: _noteList,\n'
        '          projects: _projectList,\n'
        '          routines: _routineList,\n'
        '          onChanged: () async {\n'
        '            AppDataBus.instance.lifeChanged();\n'
        '          },\n'
        '        ),\n'
        '        FinanceHub(\n'
        '          expenses: _expenseList,\n'
        '          income: _incomeList,\n'
        '          billOcc: _billOcc,\n'
        '          monthSpendMinor: _monthSpendMinor,\n'
        '          onChanged: () async {\n'
        '            AppDataBus.instance.financeChanged();\n'
        '          },\n'
        '          onPayBill: (o) async {\n'
        '            await promptAndPayBill(context, o);\n'
        '            AppDataBus.instance.financeChanged();\n'
        '          },\n'
        '        ),\n'
        '        MoreHub(onChanged: () async {\n'
        '          AppDataBus.instance.notifyDomains({\n'
        '            DataDomain.life,\n'
        '            DataDomain.finance,\n'
        '            DataDomain.today,\n'
        '            DataDomain.timeline,\n'
        '          });\n'
        '        }),\n'
        '      ],\n'
        '    );'
    )
    new_body = (
        '    return IndexedStack(\n'
        '      index: _tab,\n'
        '      children: [\n'
        "        KeyedSubtree(key: const ValueKey('tab-today'), child: _today()),\n"
        "        KeyedSubtree(key: const ValueKey('tab-tasks'), child: _tasksView()),\n"
        '        LifeHub(\n'
        "          key: const ValueKey('tab-life'),\n"
        '          goals: _goalList,\n'
        '          habits: _habitList,\n'
        '          notes: _noteList,\n'
        '          projects: _projectList,\n'
        '          routines: _routineList,\n'
        '          onChanged: () async {\n'
        '            AppDataBus.instance.lifeChanged();\n'
        '          },\n'
        '        ),\n'
        '        FinanceHub(\n'
        "          key: const ValueKey('tab-finance'),\n"
        '          expenses: _expenseList,\n'
        '          income: _incomeList,\n'
        '          billOcc: _billOcc,\n'
        '          monthSpendMinor: _monthSpendMinor,\n'
        '          onChanged: () async {\n'
        '            AppDataBus.instance.financeChanged();\n'
        '          },\n'
        '          onPayBill: (o) async {\n'
        '            await promptAndPayBill(context, o);\n'
        '            AppDataBus.instance.financeChanged();\n'
        '          },\n'
        '        ),\n'
        '        MoreHub(\n'
        "          key: const ValueKey('tab-more'),\n"
        '          onChanged: () async {\n'
        '            AppDataBus.instance.notifyDomains({\n'
        '              DataDomain.life,\n'
        '              DataDomain.finance,\n'
        '              DataDomain.today,\n'
        '              DataDomain.timeline,\n'
        '            });\n'
        '          },\n'
        '        ),\n'
        '      ],\n'
        '    );'
    )
    if old_body not in t:
        sys.exit('body marker missing')
    t = t.replace(old_body, new_body, 1)
    if t.count('(') != t.count(')'):
        sys.exit('paren mismatch')
    p.write_text(t)
    print('patched', len(t))


if __name__ == '__main__':
    main()
