"""W4: expense/income form validation, snackbars, currency label."""
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
    if 'Expense saved' in t or 'Recorded expense' in t:
        print('forms already has success snackbar')
    if "import '../../services/user_prefs.dart';" not in t:
        t = t.replace(
            "import '../../domain/enums.dart';\n",
            "import '../../domain/enums.dart';\nimport '../../services/user_prefs.dart';\n",
            1,
        )
    # Currency label
    t = t.replace(
        "labelText: 'Amount (${Defaults.currency}) *',",
        "labelText: 'Amount (${UserPrefs.instance.currency}) *',",
    )

    old = (
        '        actions: [\n'
        "          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),\n"
        '          FilledButton(\n'
        '            onPressed: () {\n'
        '              if (label.text.trim().isEmpty) return;\n'
        "              if (double.tryParse(amount.text.trim().replaceAll(',', '')) == null) return;\n"
        '              Navigator.pop(ctx, true);\n'
        '            },\n'
        "            child: const Text('Save'),\n"
        '          ),\n'
        '        ],\n'
        '      ),\n'
        '    ),\n'
        '  );\n'
        '  if (ok != true) return false;\n'
        "  final a = double.parse(amount.text.trim().replaceAll(',', ''));\n"
        '  if (isIncome) {\n'
        '    await IncomeRepository(AppDatabase.instance).create(\n'
        '      source: label.text.trim(),\n'
        '      amountMajor: a,\n'
        '      accountId: accountId,\n'
        '    );\n'
        '  } else {\n'
        '    await ExpenseRepository(AppDatabase.instance).create(\n'
        '      description: label.text.trim(),\n'
        '      amountMajor: a,\n'
        '      accountId: accountId,\n'
        '      categoryId: categoryId,\n'
        '    );\n'
        '    final alerts =\n'
        '        await NotificationService.instance.checkCategoryAfterExpense(categoryId);\n'
        '    if (alerts.isNotEmpty && context.mounted) {\n'
        '      final b = alerts.first;\n'
        '      final exceeded = b.level == BudgetAlertLevel.exceeded;\n'
        '      ScaffoldMessenger.of(context).showSnackBar(\n'
        '        SnackBar(\n'
        '          content: Text(\n'
        '            exceeded\n'
        "                ? 'Budget exceeded: ${b.categoryName ?? b.name}'\n"
        "                : 'Budget warning: ${b.categoryName ?? b.name}',\n"
        '          ),\n'
        '          backgroundColor: exceeded ? Colors.redAccent : Colors.orangeAccent,\n'
        '        ),\n'
        '      );\n'
        '    }\n'
        '  }\n'
        '  return true;\n'
        '}'
    )

    new = (
        '        actions: [\n'
        "          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),\n"
        '          FilledButton(\n'
        '            onPressed: () {\n'
        '              if (label.text.trim().isEmpty) {\n'
        '                ScaffoldMessenger.of(ctx).showSnackBar(\n'
        "                  SnackBar(content: Text(isIncome ? 'Enter a source' : 'Enter what the expense is for')),\n"
        '                );\n'
        '                return;\n'
        '              }\n'
        "              final parsed = double.tryParse(amount.text.trim().replaceAll(',', ''));\n"
        '              if (parsed == null || parsed <= 0) {\n'
        '                ScaffoldMessenger.of(ctx).showSnackBar(\n'
        "                  const SnackBar(content: Text('Enter a valid amount greater than 0')),\n"
        '                );\n'
        '                return;\n'
        '              }\n'
        '              Navigator.pop(ctx, true);\n'
        '            },\n'
        "            child: const Text('Save'),\n"
        '          ),\n'
        '        ],\n'
        '      ),\n'
        '    ),\n'
        '  );\n'
        '  if (ok != true) return false;\n'
        "  final a = double.tryParse(amount.text.trim().replaceAll(',', ''));\n"
        '  if (a == null || a <= 0) return false;\n'
        '  try {\n'
        '    if (isIncome) {\n'
        '      await IncomeRepository(AppDatabase.instance).create(\n'
        '        source: label.text.trim(),\n'
        '        amountMajor: a,\n'
        '        accountId: accountId,\n'
        '      );\n'
        '      if (context.mounted) {\n'
        '        ScaffoldMessenger.of(context).showSnackBar(\n'
        "          SnackBar(content: Text('Income recorded: ${label.text.trim()}')),\n"
        '        );\n'
        '      }\n'
        '    } else {\n'
        '      await ExpenseRepository(AppDatabase.instance).create(\n'
        '        description: label.text.trim(),\n'
        '        amountMajor: a,\n'
        '        accountId: accountId,\n'
        '        categoryId: categoryId,\n'
        '      );\n'
        '      if (context.mounted) {\n'
        '        ScaffoldMessenger.of(context).showSnackBar(\n'
        "          SnackBar(content: Text('Expense saved: ${label.text.trim()}')),\n"
        '        );\n'
        '      }\n'
        '      final alerts =\n'
        '          await NotificationService.instance.checkCategoryAfterExpense(categoryId);\n'
        '      if (alerts.isNotEmpty && context.mounted) {\n'
        '        final b = alerts.first;\n'
        '        final exceeded = b.level == BudgetAlertLevel.exceeded;\n'
        '        ScaffoldMessenger.of(context).showSnackBar(\n'
        '          SnackBar(\n'
        '            content: Text(\n'
        '              exceeded\n'
        "                  ? 'Budget exceeded: ${b.categoryName ?? b.name}'\n"
        "                  : 'Budget warning: ${b.categoryName ?? b.name}',\n"
        '            ),\n'
        '            backgroundColor: exceeded ? Colors.redAccent : Colors.orangeAccent,\n'
        '          ),\n'
        '        );\n'
        '      }\n'
        '    }\n'
        '  } catch (e) {\n'
        '    if (context.mounted) {\n'
        '      ScaffoldMessenger.of(context).showSnackBar(\n'
        "        SnackBar(content: Text('Could not save: $e')),\n"
        '      );\n'
        '    }\n'
        '    return false;\n'
        '  }\n'
        '  return true;\n'
        '}'
    )

    if old not in t:
        sys.exit('money form save block missing')
    t = t.replace(old, new, 1)
    Path(path).write_text(t)
    print('forms ok', len(t))


def patch_finance() -> None:
    path = 'apps/flutter/lib/ui/hubs/finance_hub.dart'
    t = show(path)
    # Ensure Record expense uses ok-gated refresh (W1) + keeps working
    old = (
        '        TextButton.icon(\n'
        '          onPressed: () async {\n'
        '            final ok = await showCreateForm(context, AddKind.expense);\n'
        '            if (ok) await _refresh();\n'
        '          },\n'
        '          icon: const Icon(Icons.add),\n'
        "          label: const Text('Record expense'),\n"
        '        ),'
    )
    new = (
        '        FilledButton.icon(\n'
        '          onPressed: () async {\n'
        '            final ok = await showCreateForm(context, AddKind.expense);\n'
        '            if (!mounted) return;\n'
        '            if (ok) {\n'
        '              await _refresh();\n'
        '            }\n'
        '          },\n'
        '          icon: const Icon(Icons.add),\n'
        "          label: const Text('Record expense'),\n"
        '        ),'
    )
    if old in t:
        t = t.replace(old, new, 1)
        print('finance button upgraded')
    elif 'if (ok) await _refresh()' in t:
        print('finance already ok-gated')
    else:
        # older always-refresh form
        old2 = "onPressed: () => showCreateForm(context, AddKind.expense).then((_) => _refresh()),"
        if old2 in t:
            t = t.replace(
                old2,
                'onPressed: () async {\n'
                '            final ok = await showCreateForm(context, AddKind.expense);\n'
                '            if (!mounted) return;\n'
                '            if (ok) await _refresh();\n'
                '          },',
            )
            print('finance legacy fixed')
        else:
            print('finance button pattern skip')
    Path(path).write_text(t)
    print('finance ok', len(t))


def patch_roadmap() -> None:
    path = 'ROADMAP.md'
    t = show(path)
    t = t.replace(
        '### W4 \u2014 Finance expense path\n'
        '- [ ] Record expense saves and shows on ledger\n'
        '- [ ] Confirmation snackbar; no refresh on cancel',
        '### W4 \u2014 Finance expense path\n'
        '- [ ] Record expense saves and shows on ledger (in progress)\n'
        '- [ ] Confirmation snackbar; no refresh on cancel (in progress)',
    )
    # ASCII hyphen variant
    t = t.replace(
        '### W4 — Finance expense path\n'
        '- [ ] Record expense saves and shows on ledger\n'
        '- [ ] Confirmation snackbar; no refresh on cancel',
        '### W4 — Finance expense path\n'
        '- [x] Validation feedback when amount/description missing\n'
        '- [x] Success/error snackbar after save\n'
        '- [x] Refresh ledger only when save succeeds (cancel stays put)\n'
        '- [ ] Device confirm: expense appears on Recent ledger',
    )
    Path(path).write_text(t)
    print('roadmap ok')


def main() -> None:
    patch_forms()
    patch_finance()
    patch_roadmap()


if __name__ == '__main__':
    main()
