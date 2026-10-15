import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/security_service.dart';
import 'theme.dart';
import 'widgets/glass.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onPinChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onPinChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onPinChanged() {
    final pin = _ctrl.text.trim();
    if (_busy) return;
    if (pin.length < 4) {
      if (_error != null) setState(() => _error = null);
      return;
    }
    // Auto-verify once the user has entered a candidate PIN (4–12 digits).
    _tryUnlock(pin);
  }

  Future<void> _tryUnlock(String pin) async {
    if (_busy) return;
    final attempt = ++_attempt;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await SecurityService.instance.verifyPin(pin);
    if (!mounted || attempt != _attempt) return;
    if (ok) {
      widget.onUnlocked();
      return;
    }
    // Only show error if the field still holds the same failed value
    // (user may still be typing a longer PIN).
    if (_ctrl.text.trim() == pin) {
      setState(() {
        _error = 'Incorrect PIN';
        _busy = false;
      });
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, color: AppTheme.brandBlue, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'Personal Life OS',
                        style: TextStyle(
                          color: AppTheme.silver,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter PIN to unlock offline data',
                        style: TextStyle(
                          color: AppTheme.silver.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _ctrl,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 12,
                        autofocus: true,
                        enabled: !_busy || _error != null,
                        style: const TextStyle(color: AppTheme.silver, letterSpacing: 6),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          counterText: '',
                          labelText: 'PIN',
                          labelStyle: TextStyle(color: AppTheme.silverMuted),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      ],
                      if (_busy && _error == null) ...[
                        const SizedBox(height: 16),
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.brandBlue,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Text(
                          'Unlocks automatically when the PIN is correct',
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.35),
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Data never leaves this device',
                        style: TextStyle(
                          color: AppTheme.silver.withValues(alpha: 0.35),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
