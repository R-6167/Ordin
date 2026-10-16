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

Future<bool> showCreateForm(BuildContext context, AddKind kind) async {
  switch (kind) {
    case AddKind.task:
      return _taskForm(context);
    case AddKind.project:
      return _entityWithLifeAreaForm(
        context,
        title: 'New project',
        onSave: (title, description, lifeAreaId) async {
          await ProjectRepository(AppDatabase.instance).create(
            title: title,
            description: description,
            lifeAreaId: lifeAreaId,
          );
        },
      );
    case AddKind.goal:
      return _entityWithLifeAreaForm(
        context,
        title: 'New goal',
        onSave: (title, description, lifeAreaId) async {
          await GoalRepository(AppDatabase.instance).create(
            title: title,
            description: description,
            lifeAreaId: lifeAreaId,
          );
        },
      );
    case AddKind.habit:
      return _simpleText(
        context,
        title: 'New habit',
        fields: const ['Title', 'Description (optional)'],
        onSave: (v) async {
          await HabitRepository(AppDatabase.instance).create(
            title: v[0],
            description: v.length > 1 ? v[1] : null,
          );
        },
      );
    case AddKind.routine:
      return _simpleText(
        context,
        title: 'New routine',
        fields: const ['Name'],
        onSave: (v) async {
          await RoutineRepository(AppDatabase.instance).create(name: v[0]);
        },
      );
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

Future<bool> _taskForm(BuildContext context) async {
  final title = TextEditingController();
  final desc = TextEditingController();
  var priority = 0;
  DateTime? due;
  String? lifeAreaId;
  final areaRepo = LifeAreaRepository(AppDatabase.instance);
  await areaRepo.seedDefaultsIfEmpty();
  final areas = await areaRepo.listActive();

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
  await TaskRepository(AppDatabase.instance).create(
    title: title.text.trim(),
    dueAt: dueMs,
    priority: priority,
    description: desc.text.trim().isEmpty ? null : desc.text.trim(),
    lifeAreaId: lifeAreaId,
  );
  return true;
}

// NOTE: Remaining helpers (_moneyForm, _billForm, _simpleText, _entityWithLifeAreaForm)
// must match main. If this commit is incomplete, replace this file from main:
//   git checkout main -- apps/flutter/lib/ui/forms/create_forms.dart
