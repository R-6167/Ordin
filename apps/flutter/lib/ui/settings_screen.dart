import 'package:flutter/material.dart';

import '../data/database.dart';
import '../domain/enums.dart';
import '../services/backup_io.dart';
import '../services/data_management.dart';
import '../services/notification_service.dart';
import '../services/security_service.dart';
import '../services/user_prefs.dart';
import 'app_meta.dart';
import 'screens/ai_settings_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'theme.dart';
import 'widgets/glass.dart';
import 'widgets/settings_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name = 'Me';
  String _currency = Defaults.currency;
  int _weekStart = Defaults.weekStartDay;
  bool _loading = true;
  bool _lockEnabled = false;
  bool _hideBalances = false;
  int _autoLock = 5;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await SecurityService.instance.load();
    final db = await AppDatabase.instance.database;
    final rows = await db.query('users', limit: 1);
    if (rows.isNotEmpty) {
      setState(() {
        _name = (rows.first['display_name'] as String?) ??
            (rows.first['name'] as String?) ??
            'Me';
        _currency = (rows.first['currency'] as String?) ?? Defaults.currency;
        _weekStart = (rows.first['week_start_day'] as int?) ?? Defaults.weekStartDay;
        _lockEnabled = SecurityService.instance.lockEnabled;
        _hideBalances = SecurityService.instance.hideBalances;
        _autoLock = SecurityService.instance.autoLockMinutes;
        _loading = false;
      });
    } else {
      setState(() {
        _lockEnabled = SecurityService.instance.lockEnabled;
        _hideBalances = SecurityService.instance.hideBalances;
        _autoLock = SecurityService.instance.autoLockMinutes;
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile({String? name, String? currency, int? weekStart}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('users', limit: 1);
    if (rows.isEmpty) return;
    final id = rows.first['id'] as String;
    await db.update(
      'users',
      {
        if (name != null) 'display_name': name,
        if (currency != null) 'currency': currency,
        if (weekStart != null) 'week_start_day': weekStart,
        'updated_at': AppDatabase.nowMs(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    UserPrefs.instance.applyLocal(currency: currency, weekStartDay: weekStart, displayName: name);
    await UserPrefs.instance.load();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved offline')));
    }
  }

  Future<void> _setPin() async {
    final hasExisting = SecurityService.instance.hasPin;
    final current = TextEditingController();
    final a = TextEditingController();
    final b = TextEditingController();
    String? dialogError;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            backgroundColor: AppTheme.metal,
            title: Text(hasExisting ? 'Change PIN' : 'Set PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasExisting)
                  TextField(
                    controller: current,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.silver),
                    decoration: const InputDecoration(
                      labelText: 'Current PIN',
                      labelStyle: TextStyle(color: AppTheme.silverMuted),
                    ),
                  ),
                TextField(
                  controller: a,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  autofocus: !hasExisting,
                  style: const TextStyle(color: AppTheme.silver),
                  decoration: const InputDecoration(
                    labelText: 'New PIN (4–12 digits)',
                    labelStyle: TextStyle(color: AppTheme.silverMuted),
                  ),
                ),
                TextField(
                  controller: b,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppTheme.silver),
                  decoration: const InputDecoration(
                    labelText: 'Confirm new PIN',
                    labelStyle: TextStyle(color: AppTheme.silverMuted),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(dialogError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (a.text.trim() != b.text.trim()) {
                    setLocal(() => dialogError = 'PINs do not match');
                    return;
                  }
                  if (hasExisting) {
                    final valid = await SecurityService.instance.verifyPin(current.text.trim());
                    if (!valid) {
                      setLocal(() => dialogError = 'Current PIN is incorrect');
                      return;
                    }
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true) return;
    try {
      await SecurityService.instance.setPin(a.text.trim());
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(hasExisting ? 'PIN changed' : 'PIN set — lock enabled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _removePin() async {
    final current = TextEditingController();
    String? dialogError;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            backgroundColor: AppTheme.metal,
            title: const Text('Remove PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your current PIN to disable app lock.',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.7), fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: current,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(color: AppTheme.silver),
                  decoration: const InputDecoration(
                    labelText: 'Current PIN',
                    labelStyle: TextStyle(color: AppTheme.silverMuted),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(dialogError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () async {
                  final valid = await SecurityService.instance.verifyPin(current.text.trim());
                  if (!valid) {
                    setLocal(() => dialogError = 'Current PIN is incorrect');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Remove'),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true) return;
    await SecurityService.instance.clearPin();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN removed — app lock disabled')),
      );
    }
  }

  Future<void> _export({bool encrypted = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    String? passphrase;
    if (encrypted) {
      final pass = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Encrypt backup'),
          content: TextField(
            controller: pass,
            obscureText: true,
            style: const TextStyle(color: AppTheme.silver),
            decoration: const InputDecoration(
              labelText: 'Passphrase (min 6 chars)',
              helperText: 'You will need this to restore',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Encrypt')),
          ],
        ),
      );
      if (ok != true) {
        setState(() => _busy = false);
        return;
      }
      passphrase = pass.text;
    }
    final result = await BackupIo(AppDatabase.instance).exportToFile(
      encrypted: encrypted,
      passphrase: passphrase,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<String?> _promptBackupPassphrase() async {
    final pass = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Encrypted backup', style: TextStyle(color: AppTheme.silver)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This backup is encrypted. Enter the passphrase used when it was exported.',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.7), fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pass,
              obscureText: true,
              autofocus: true,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(
                labelText: 'Passphrase',
                labelStyle: TextStyle(color: AppTheme.silverMuted),
                helperText: 'Required to decrypt and restore',
                helperStyle: TextStyle(color: AppTheme.silverMuted),
              ),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Decrypt & import')),
        ],
      ),
    );
    if (ok != true) return null;
    return pass.text;
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    final io = BackupIo(AppDatabase.instance);
    var result = await io.importFromFile();

    if (result.needsPassphrase) {
      if (!mounted) return;
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;

      final raw = result.pendingRaw;
      if (raw == null || raw.isEmpty) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Encrypted backup detected, but the file could not be re-read. Try again.'),
          ),
        );
        return;
      }

      final passphrase = await _promptBackupPassphrase();
      if (passphrase == null || passphrase.isEmpty) {
        result = BackupIoResult(ok: false, message: 'Import cancelled — passphrase required');
      } else {
        result = await io.importEncryptedRaw(raw, passphrase);
      }
    }

    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _wipe() async {
    final typed = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Wipe all local data?', style: TextStyle(color: Colors.redAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your offline database and PIN on this device. Export a backup first.',
              style: TextStyle(color: AppTheme.silver),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: typed,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(labelText: 'Type WIPE to confirm'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              if (typed.text.trim().toUpperCase() != 'WIPE') return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Wipe'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await DataManagement.wipeAllLocalData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local data wiped. Restart the app.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Settings')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_busy) const LinearProgressIndicator(color: AppTheme.brandBlue),
                  SwitchListTile(
                    title: const Text('Local notifications', style: TextStyle(color: AppTheme.silver)),
                    subtitle: Text(
                      'Reminders, bills, budgets, overdue',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
                    ),
                    value: NotificationService.instance.enabled,
                    activeColor: AppTheme.brandBlue,
                    onChanged: (v) async {
                      NotificationService.instance.enabled = v;
                      try {
                        if (v) {
                          await NotificationService.instance.init();
                          final n = await NotificationService.instance.syncFromDatabase();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Scheduled $n notifications')),
                            );
                          }
                        } else {
                          await NotificationService.instance.cancelAll();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Notifications: $e')),
                          );
                        }
                      }
                      setState(() {});
                    },
                  ),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Security', style: Theme.of(context).textTheme.titleMedium),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('App lock', style: TextStyle(color: AppTheme.silver)),
                          subtitle: Text(
                            SecurityService.instance.hasPin
                                ? 'PIN required on open'
                                : 'Set a PIN first',
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
                          ),
                          value: _lockEnabled && SecurityService.instance.hasPin,
                          activeColor: AppTheme.brandBlue,
                          onChanged: (v) async {
                            try {
                              if (v && !SecurityService.instance.hasPin) {
                                await _setPin();
                                return;
                              }
                              await SecurityService.instance.setLockEnabled(v);
                              await _load();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                              }
                            }
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            SecurityService.instance.hasPin ? 'Change PIN' : 'Set PIN',
                            style: const TextStyle(color: AppTheme.silver),
                          ),
                          trailing: const Icon(Icons.pin, color: AppTheme.brandBlue),
                          onTap: _setPin,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto-lock', style: TextStyle(color: AppTheme.silver)),
                          subtitle: Text(
                            _autoLock == 0 ? 'Only when app is killed' : 'After $_autoLock min in background',
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
                          ),
                          onTap: () async {
                            final next = await showDialog<int>(
                              context: context,
                              builder: (ctx) => SimpleDialog(
                                title: const Text('Auto-lock after'),
                                children: [
                                  for (final m in [0, 1, 5, 15, 30])
                                    SimpleDialogOption(
                                      onPressed: () => Navigator.pop(ctx, m),
                                      child: Text(m == 0 ? 'Off (cold start only)' : '$m minutes'),
                                    ),
                                ],
                              ),
                            );
                            if (next != null) {
                              await SecurityService.instance.setAutoLockMinutes(next);
                              await _load();
                            }
                          },
                        ),
                        if (SecurityService.instance.hasPin)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Remove PIN', style: TextStyle(color: Colors.redAccent)),
                            onTap: _removePin,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Privacy', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Everything stays on this device. No accounts, no cloud sync.',
                          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 13),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Hide balances in UI', style: TextStyle(color: AppTheme.silver)),
                          value: _hideBalances,
                          activeColor: AppTheme.brandBlue,
                          onChanged: (v) async {
                            await SecurityService.instance.setHideBalances(v);
                            await _load();
                          },
                        ),
                      ],
                    ),
                  ),
                  SettingsPreferencesCard(
                    currency: _currency,
                    weekStart: _weekStart,
                    onCurrency: (c) => _saveProfile(currency: c),
                    onWeekStart: (w) => _saveProfile(weekStart: w),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Profile', style: Theme.of(context).textTheme.titleMedium),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Display name'),
                          subtitle: Text(_name),
                          trailing: const Icon(Icons.edit, size: 18),
                          onTap: () async {
                            final c = TextEditingController(text: _name);
                            final ok = await showDialog<String>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Display name'),
                                content: TextField(controller: c, autofocus: true),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, c.text.trim()),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != null && ok.isNotEmpty) await _saveProfile(name: ok);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Backup', style: Theme.of(context).textTheme.titleMedium),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Export backup', style: TextStyle(color: AppTheme.silver)),
                          trailing: const Icon(Icons.upload_file, color: AppTheme.brandBlue),
                          onTap: () => _export(encrypted: false),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Export encrypted backup', style: TextStyle(color: AppTheme.silver)),
                          trailing: const Icon(Icons.lock, color: AppTheme.brandBlue),
                          onTap: () => _export(encrypted: true),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Import backup', style: TextStyle(color: AppTheme.silver)),
                          trailing: const Icon(Icons.download, color: AppTheme.brandBlue),
                          onTap: _import,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Danger zone', style: Theme.of(context).textTheme.titleMedium),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Wipe all local data', style: TextStyle(color: Colors.redAccent)),
                          onTap: _wipe,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Diagnostics', style: TextStyle(color: AppTheme.silver)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                    ),
                  ),
                  ListTile(
                    title: const Text('AI settings', style: TextStyle(color: AppTheme.silver)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      AppMeta.versionLabel,
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35), fontSize: 11),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
