import 'package:flutter/material.dart';

import '../../data/account_repository.dart';
import '../../data/bill_repository.dart';
import '../../data/budget_repository.dart';
import '../../data/category_repository.dart';
import '../../data/database.dart';
import '../../data/expense_repository.dart';
import '../../data/extended_repository.dart';
import '../../data/goal_repository.dart';
import '../../data/life_area_repository.dart';
import '../../data/habit_repository.dart';
import '../../data/income_repository.dart';
import '../../data/note_repository.dart';
import '../../data/project_repository.dart';
import '../../data/routine_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/enums.dart';
import '../../services/user_prefs.dart';
import '../../services/notification_service.dart';
import '../theme.dart';
import '../screens/note_detail_screen.dart';

enum AddKind {
  task,
  project,
  goal,
  habit,
  routine,
  event,
  note,
  expense,
  income,
  bill,
  person,
  reminder,
}

/// Returns the created [AddKind] on success, or null if cancelled.
Future<AddKind?> showUniversalAdd(BuildContext context) async {
  final kind = await showModalBottomSheet<AddKind>(
    context: context,
    backgroundColor: AppTheme.metal,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.silver.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'What do you want to add?',
              style: TextStyle(color: AppTheme.silver, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in [
                  (AddKind.task, Icons.check_box_outlined, 'Task'),
                  (AddKind.project, Icons.folder_outlined, 'Project'),
                  (AddKind.goal, Icons.flag_outlined, 'Goal'),
                  (AddKind.habit, Icons.repeat, 'Habit'),
                  (AddKind.routine, Icons.playlist_play, 'Routine'),
                  (AddKind.event, Icons.event, 'Event'),
                  (AddKind.note, Icons.note_outlined, 'Note'),
                  (AddKind.expense, Icons.arrow_upward, 'Expense'),
                  (AddKind.income, Icons.arrow_downward, 'Income'),
                  (AddKind.bill, Icons.receipt_long, 'Bill'),
                  (AddKind.person, Icons.person_outline, 'Person'),
                  (AddKind.reminder, Icons.alarm, 'Reminder'),
                ])
                  ActionChip(
                    avatar: Icon(e.$2, size: 18, color: AppTheme.amber),
                    label: Text(e.$3),
                    onPressed: () => Navigator.pop(ctx, e.$1),
                    backgroundColor: AppTheme.metalDeep,
                    side: BorderSide(color: AppTheme.silver.withValues(alpha: 0.2)),
                    labelStyle: const TextStyle(color: AppTheme.silver),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (kind == null || !context.mounted) return null;
  final ok = await showCreateForm(context, kind);
  return ok ? kind : null;
}

Future<bool> showCreateForm(
  BuildContext context,
  AddKind kind, {
  String? lifeAreaId,
}) async {
  switch (kind) {
    case AddKind.task:
      return _taskForm(context, initialLifeAreaId: lifeAreaId);
    case AddKind.project:
      return _projectForm(context, initialLifeAreaId: lifeAreaId);
    case AddKind.goal:
      return _entityWithLifeAreaForm(
        context,
        title: 'New goal',
        initialLifeAreaId: lifeAreaId,
        onSave: (title, description, areaId) async {
          await GoalRepository(AppDatabase.instance).create(
            title: title,
            description: description,
            lifeAreaId: areaId,
          );
        },
      );
    case AddKind.habit:
      return _habitForm(context, initialLifeAreaId: lifeAreaId);
    case AddKind.routine:
      return _routineForm(context, initialLifeAreaId: lifeAreaId);
    case AddKind.event:
      return _simpleText(
        context,
        title: 'New event',
        fields: const ['Title'],
        onSave: (v) async {
          await ExtendedRepository(AppDatabase.instance).addEvent(title: v[0]);
        },
      );
    case AddKind.note:
      // Full note editor (multiline + links + turn-to-tasks), not a one-line dialog.
      return _openNewNoteEditor(context);
    case AddKind.expense:
      return _moneyForm(context, isIncome: false);
    case AddKind.income:
      return _moneyForm(context, isIncome: true);
    case AddKind.bill:
      return _billForm(context);
    case AddKind.person:
      return _simpleText(
        context,
        title: 'New person',
        fields: const ['Name', 'Phone (optional)'],
        onSave: (v) async {
          await ExtendedRepository(AppDatabase.instance).addPerson(
            v[0],
            phone: v.length > 1 && v[1].isNotEmpty ? v[1] : null,
          );
        },
      );
    case AddKind.reminder:
      return _simpleText(
        context,
        title: 'New reminder',
        fields: const ['Title'],
        onSave: (v) async {
          await ExtendedRepository(AppDatabase.instance).addReminder(v[0]);
        },
      );
  }
}


Future<bool> _openNewNoteEditor(BuildContext context) async {
  final note = await NoteRepository(AppDatabase.instance).create(content: '');
  if (!context.mounted) return false;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => NoteDetailScreen(noteId: note.id)),
  );
  return true;
}

Future<bool> _taskForm(BuildContext context, {String? initialLifeAreaId, String? initialProjectId}) async {
  final title = TextEditingController();
  final desc = TextEditingController();
  var priority = 0;
  DateTime? due;
  String? lifeAreaId = initialLifeAreaId;
  String? projectId = initialProjectId;
  final areaRepo = LifeAreaRepository(AppDatabase.instance);
  await areaRepo.seedDefaultsIfEmpty();
  final areas = await areaRepo.listActive();
  final projects = await ProjectRepository(AppDatabase.instance).listActive();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('New task', style: TextStyle(color: AppTheme.silver)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: desc,
                style: const TextStyle(color: AppTheme.silver),
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: lifeAreaId,
                dropdownColor: AppTheme.metal,
                decoration: const InputDecoration(labelText: 'Life area (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...areas.map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.title)),
                  ),
                ],
                onChanged: (v) => setLocal(() => lifeAreaId = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: projectId,
                dropdownColor: AppTheme.metal,
                decoration: const InputDecoration(
                  labelText: 'Project (optional)',
                  helperText: 'Links into Goal → Project → Task',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...projects.map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.title)),
                  ),
                ],
                onChanged: (v) => setLocal(() => projectId = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: priority,
                dropdownColor: AppTheme.metal,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Normal')),
                  DropdownMenuItem(value: 1, child: Text('High')),
                  DropdownMenuItem(value: 2, child: Text('Urgent')),
                ],
                onChanged: (v) => setLocal(() => priority = v ?? 0),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  due == null
                      ? 'Due date (optional)'
                      : 'Due: ${due!.year}-${due!.month.toString().padLeft(2, '0')}-${due!.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppTheme.silver, fontSize: 14),
                ),
                trailing: const Icon(Icons.calendar_today, color: AppTheme.amber, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setLocal(() => due = picked);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  if (ok != true) return false;
  final dueMs = due == null
      ? null
      : DateTime(due!.year, due!.month, due!.day, 23, 59).millisecondsSinceEpoch;
  String? goalId;
  if (projectId != null) {
    try {
      final projects = await ProjectRepository(AppDatabase.instance).listActive();
      for (final p in projects) {
        if (p.id == projectId) {
          goalId = p.goalId;
          break;
        }
      }
    } catch (_) {}
  }
  await TaskRepository(AppDatabase.instance).create(
    title: title.text.trim(),
    dueAt: dueMs,
    priority: priority,
    description: desc.text.trim().isEmpty ? null : desc.text.trim(),
    lifeAreaId: lifeAreaId,
    projectId: projectId,
    goalId: goalId,
  );
  return true;
}

Future<bool> _moneyForm(BuildContext context, {required bool isIncome}) async {
  final label = TextEditingController();
  final amount = TextEditingController();
  List<Map<String, Object?>> accounts = const [];
  List<Map<String, Object?>> categories = const [];
  try {
    accounts = await AccountRepository(AppDatabase.instance).list();
  } catch (_) {}
  if (!isIncome) {
    try {
      categories = await CategoryRepository(AppDatabase.instance).listExpense();
    } catch (_) {}
  }
  String? accountId;
  String? categoryId = categories.isEmpty ? null : categories.first['id'] as String?;

  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: Text(
          isIncome ? 'Record income' : 'Record expense',
          style: const TextStyle(color: AppTheme.silver),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: label,
                autofocus: true,
                style: const TextStyle(color: AppTheme.silver),
                decoration: InputDecoration(
                  labelText: isIncome ? 'Source *' : 'What for? *',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.silver),
                decoration: InputDecoration(
                  labelText: 'Amount (${UserPrefs.instance.currency}) *',
                ),
              ),
              if (!isIncome && categories.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: categoryId,
                  dropdownColor: AppTheme.metal,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...categories.map(
                      (c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text('${c['name']}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => categoryId = v),
                ),
              ],
              if (accounts.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: accountId,
                  dropdownColor: AppTheme.metal,
                  decoration: const InputDecoration(labelText: 'Account (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...accounts.map(
                      (a) => DropdownMenuItem(
                        value: a['id'] as String,
                        child: Text('${a['name']}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => accountId = v),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (label.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(isIncome ? 'Enter a source' : 'Enter what the expense is for')),
                );
                return;
              }
              final parsed = double.tryParse(amount.text.trim().replaceAll(',', ''));
              if (parsed == null || parsed <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter a valid amount greater than 0')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return false;
  final a = double.tryParse(amount.text.trim().replaceAll(',', ''));
  if (a == null || a <= 0) return false;
  try {
    if (isIncome) {
      await IncomeRepository(AppDatabase.instance).create(
        source: label.text.trim(),
        amountMajor: a,
        accountId: accountId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Income recorded: ${label.text.trim()}')),
        );
      }
    } else {
      await ExpenseRepository(AppDatabase.instance).create(
        description: label.text.trim(),
        amountMajor: a,
        accountId: accountId,
        categoryId: categoryId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Expense saved: ${label.text.trim()}')),
        );
      }
      final alerts =
          await NotificationService.instance.checkCategoryAfterExpense(categoryId);
      if (alerts.isNotEmpty && context.mounted) {
        final b = alerts.first;
        final exceeded = b.level == BudgetAlertLevel.exceeded;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              exceeded
                  ? 'Budget exceeded: ${b.categoryName ?? b.name}'
                  : 'Budget warning: ${b.categoryName ?? b.name}',
            ),
            backgroundColor: exceeded ? Colors.redAccent : Colors.orangeAccent,
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
    return false;
  }
  return true;
}

Future<bool> _billForm(BuildContext context) async {
  final name = TextEditingController();
  final amount = TextEditingController();
  var dueInDays = 7;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('New bill', style: TextStyle(color: AppTheme.silver)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(labelText: 'Name *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.silver),
              decoration: InputDecoration(
                labelText: 'Expected amount (${Defaults.currency})',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: dueInDays,
              dropdownColor: AppTheme.metal,
              decoration: const InputDecoration(labelText: 'Due in'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 day')),
                DropdownMenuItem(value: 3, child: Text('3 days')),
                DropdownMenuItem(value: 7, child: Text('1 week')),
                DropdownMenuItem(value: 14, child: Text('2 weeks')),
                DropdownMenuItem(value: 30, child: Text('1 month')),
              ],
              onChanged: (v) => setLocal(() => dueInDays = v ?? 7),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return false;
  final major = double.tryParse(amount.text.trim().replaceAll(',', ''));
  await BillRepository(AppDatabase.instance).create(
    name: name.text.trim(),
    expectedMajor: major,
    dueInDays: dueInDays,
  );
  return true;
}

Future<bool> _simpleText(
  BuildContext context, {
  required String title,
  required List<String> fields,
  required Future<void> Function(List<String>) onSave,
}) async {
  final ctrls = List.generate(fields.length, (_) => TextEditingController());
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.metal,
      title: Text(title, style: const TextStyle(color: AppTheme.silver)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            TextField(
              controller: ctrls[i],
              autofocus: i == 0,
              style: const TextStyle(color: AppTheme.silver),
              decoration: InputDecoration(labelText: fields[i]),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (ctrls.first.text.trim().isEmpty) return;
            Navigator.pop(ctx, true);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await onSave(ctrls.map((c) => c.text.trim()).toList());
  return true;
}


Future<bool> _habitForm(BuildContext context, {String? initialLifeAreaId}) async {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String? lifeAreaId = initialLifeAreaId;
  final areaRepo = LifeAreaRepository(AppDatabase.instance);
  await areaRepo.seedDefaultsIfEmpty();
  final areas = await areaRepo.listActive();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('New habit', style: TextStyle(color: AppTheme.silver)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(labelText: 'Title *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: lifeAreaId,
              dropdownColor: AppTheme.metal,
              decoration: const InputDecoration(labelText: 'Life area (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...areas.map((a) => DropdownMenuItem(value: a.id, child: Text(a.title))),
              ],
              onChanged: (v) => setLocal(() => lifeAreaId = v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return false;
  await HabitRepository(AppDatabase.instance).create(
    title: titleCtrl.text.trim(),
    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
    lifeAreaId: lifeAreaId,
  );
  return true;
}

Future<bool> _routineForm(BuildContext context, {String? initialLifeAreaId}) async {
  final nameCtrl = TextEditingController();
  String? lifeAreaId = initialLifeAreaId;
  final areaRepo = LifeAreaRepository(AppDatabase.instance);
  await areaRepo.seedDefaultsIfEmpty();
  final areas = await areaRepo.listActive();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('New routine', style: TextStyle(color: AppTheme.silver)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(labelText: 'Name *'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: lifeAreaId,
              dropdownColor: AppTheme.metal,
              decoration: const InputDecoration(labelText: 'Life area (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...areas.map((a) => DropdownMenuItem(value: a.id, child: Text(a.title))),
              ],
              onChanged: (v) => setLocal(() => lifeAreaId = v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return false;
  await RoutineRepository(AppDatabase.instance).create(
    name: nameCtrl.text.trim(),
    lifeAreaId: lifeAreaId,
  );
  return true;
}

Future<bool> _entityWithLifeAreaForm(
  BuildContext context, {
  required String title,
  required Future<void> Function(String title, String? description, String? lifeAreaId) onSave,
  String? initialLifeAreaId,
}) async {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String? lifeAreaId = initialLifeAreaId;
  final areaRepo = LifeAreaRepository(AppDatabase.instance);
  await areaRepo.seedDefaultsIfEmpty();
  final areas = await areaRepo.listActive();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: Text(title, style: const TextStyle(color: AppTheme.silver)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: lifeAreaId,
              dropdownColor: AppTheme.metal,
              decoration: const InputDecoration(labelText: 'Life area (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...areas.map(
                  (a) => DropdownMenuItem(value: a.id, child: Text(a.title)),
                ),
              ],
              onChanged: (v) => setLocal(() => lifeAreaId = v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return false;
  final desc = descCtrl.text.trim();
  await onSave(
    titleCtrl.text.trim(),
    desc.isEmpty ? null : desc,
    lifeAreaId,
  );
  return true;
}

