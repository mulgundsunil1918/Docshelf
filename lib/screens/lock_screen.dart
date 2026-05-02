import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import 'main_shell.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, this.onUnlocked});

  /// If supplied, called when the user unlocks. If null, the screen pushes
  /// [MainShell] itself.
  final VoidCallback? onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _showingPin = false;
  String _pin = '';
  String? _error;
  Timer? _lockoutTicker;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  @override
  void dispose() {
    _lockoutTicker?.cancel();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final available = await AuthService.instance.isBiometricAvailable();
    if (!available) {
      setState(() => _showingPin = true);
      return;
    }
    final ok = await AuthService.instance.authenticateBiometric();
    if (!mounted) return;
    if (ok) {
      _onUnlocked();
    } else {
      setState(() => _showingPin = true);
    }
  }

  void _onUnlocked() {
    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  Future<void> _onDigit(String d) async {
    if (AuthService.instance.isLockedOut()) {
      _startLockoutTicker();
      return;
    }
    if (_pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final ok = await AuthService.instance.verifyPin(_pin);
      if (!mounted) return;
      if (ok) {
        _onUnlocked();
        return;
      }
      if (AuthService.instance.isLockedOut()) {
        _startLockoutTicker();
      }
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _error = AuthService.instance.isLockedOut()
            ? 'Too many wrong attempts. Try again in ${AuthService.instance.secondsUntilUnlock()}s.'
            : 'Wrong PIN. Try again.';
      });
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _startLockoutTicker() {
    _lockoutTicker?.cancel();
    _secondsRemaining = AuthService.instance.secondsUntilUnlock();
    setState(() {});
    _lockoutTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      _secondsRemaining = AuthService.instance.secondsUntilUnlock();
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining <= 0) {
          _error = null;
          t.cancel();
        } else {
          _error = 'Try again in ${_secondsRemaining}s.';
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.lock,
                  size: 40,
                  color: AppColors.white,
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.06, 1.06),
                    duration: 1400.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 24),
              Text(
                'Unlock DocShelf',
                style: GoogleFonts.nunito(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _showingPin
                    ? 'Enter your 4-digit PIN'
                    : 'Use your fingerprint or face',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 28),
              if (_showingPin) ...[
                _LockPinDots(filled: _pin.length, error: _error != null),
                const SizedBox(height: 12),
                SizedBox(
                  height: 24,
                  child: _error == null
                      ? const SizedBox.shrink()
                      : Text(
                          _error!,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: () => setState(() => _showingPin = true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('Use PIN instead'),
                  ),
                ),
              const Spacer(),
              if (_showingPin)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _LockNumPad(
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                    onBiometric: _tryBiometric,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: ElevatedButton.icon(
                    onPressed: _tryBiometric,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Authenticate'),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockPinDots extends StatelessWidget {
  const _LockPinDots({required this.filled, required this.error});

  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 9),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: i < filled
                  ? (error ? AppColors.accent : AppColors.white)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: error
                    ? AppColors.accent
                    : AppColors.white.withValues(alpha: 0.7),
                width: 2,
              ),
            ),
          ),
      ],
    );
  }
}

class _LockNumPad extends StatelessWidget {
  const _LockNumPad({
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    final keys = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      'BIO', '0', '⌫',
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (_, i) {
        final k = keys[i];
        if (k == 'BIO') {
          return _Key(
            child: const Icon(Icons.fingerprint, color: AppColors.white),
            onTap: onBiometric,
          );
        }
        if (k == '⌫') {
          return _Key(
            child: const Icon(Icons.backspace_outlined, color: AppColors.white),
            onTap: onBackspace,
          );
        }
        return _Key(
          child: Text(
            k,
            style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
            ),
          ),
          onTap: () => onDigit(k),
        );
      },
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.18),
            ),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
