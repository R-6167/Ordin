import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/error_log_service.dart';
import 'services/first_run_tip.dart';
import 'services/local_analytics.dart';
import 'services/notification_router.dart';
import 'services/notification_service.dart';
import 'services/offline_runtime.dart';
import 'services/security_service.dart';
import 'services/user_prefs.dart';
import 'ui/home_shell.dart';
import 'ui/lock_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorLogService.instance.install();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  try {
    await NotificationService.instance.init();
  } catch (_) {}
  await SecurityService.instance.load();
  await UserPrefs.instance.load();
  try {
    await OfflineRuntime.instance.runMaintenance();
  } catch (_) {}
  runApp(const OrdinApp());
}

class OrdinApp extends StatefulWidget {
  const OrdinApp({super.key});

  @override
  State<OrdinApp> createState() => _OrdinAppState();
}

class _OrdinAppState extends State<OrdinApp> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _tipScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final sec = SecurityService.instance;
    _unlocked = !(sec.lockEnabled && sec.hasPin);
    LocalAnalytics.instance.track('app_open');
    if (_unlocked) _scheduleFirstRunTip();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      SecurityService.instance.markBackground();
      LocalAnalytics.instance.track('app_background');
    }
    if (state == AppLifecycleState.resumed) {
      LocalAnalytics.instance.track('app_resume');
      OfflineRuntime.instance.runMaintenance();
      if (SecurityService.instance.shouldLockOnResume()) {
        setState(() => _unlocked = false);
      }
    }
  }

  void _scheduleFirstRunTip() {
    if (_tipScheduled) return;
    _tipScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstRunTipIfNeeded());
  }

  Future<void> _showFirstRunTipIfNeeded() async {
    final tip = FirstRunTip.instance;
    if (!tip.isLoaded) await tip.load();
    if (!tip.shouldShow) return;
    final nav = NotificationRouter.navigatorKey.currentState;
    if (nav == null) return;
    final ctx = nav.context;
    await showDialog<void>(
      context: ctx,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surfaceRaised,
        title: const Text('Welcome to Ordin'),
        content: const Text(
          'Everything stays on this device. Start from Today, explore Life for goals and Finance, and use Timeline for your history.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
    await tip.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ordin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      navigatorKey: NotificationRouter.navigatorKey,
      // Cap extreme accessibility text scale so empty states / cards stay usable
      // (system 2.0x was rendering "No open tasks" as a full-screen headline).
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final clamped = mq.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.35,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: clamped),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _unlocked
          ? const HomeShell()
          : LockScreen(
              onUnlocked: () {
                LocalAnalytics.instance.track('app_unlock');
                OfflineRuntime.instance.runMaintenance();
                setState(() => _unlocked = true);
                _scheduleFirstRunTip();
              },
            ),
    );
  }
}
