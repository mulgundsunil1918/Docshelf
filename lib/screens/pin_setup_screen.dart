import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import '../utils/app_colors.dart';
import 'family_setup_screen.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({
    super.key,
    this.fromSettings = false,
    this.requireOldPin = false,
  });

  final bool fromSettings;
  final bool requireOldPin;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = '';
  String? _firstPin;
  String? _error;
  bool _verifyingOld = false;

  @override
  void initState() {
    super.initState();
    _verifyingOld = widget.requireOldPin;
  }

  // ─── State machine ──────────────────────────────────────────────────
  String get _title {
    if (_verifyingOld) return 'Enter your current PIN';
    if (_firstPin == null) return 'Set a 4-digit PIN';
    return 'Confirm your PIN';
  }

  String get _subtitle {
    if (_verifyingOld) return 'Verify it\'s you before changing the PIN.';
    if (_firstPin == null) {
      return widget.fromSettings
          ? 'You\'ll use this if biometric isn\'t available.'
          : 'We\'ll use this if biometric isn\'t available.';
    }
    return 'Re-enter the same 4 digits.';
  }

  Future<void> _onDigit(String d) async {
    if (_pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      _process();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _process() async {
    if (_verifyingOld) {
      final ok = await AuthService.instance.verifyPin(_pin);
      if (!mounted) return;
      if (!ok) {
        _shake('Wrong PIN. Try again.');
        return;
      }
      setState(() {
        _verifyingOld = false;
        _pin = '';
      });
      return;
    }

    if (_firstPin == null) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
      });
      return;
    }

    if (_pin == _firstPin) {
      await AuthService.instance.setPin(_pin);
      await OnboardingService.instance.setBiometricEnabled(true);
      if (!mounted) return;
      if (widget.fromSettings) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN updated.')),
        );
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FamilySetupScreen()),
        );
      }
    } else {
      _shake("PINs don't match. Start again.");
      setState(() {
        _firstPin = null;
      });
    }
  }

  Future<void> _skip() async {
    await OnboardingService.instance.setHasSetPin(false);
    await OnboardingService.instance.setBiometricEnabled(true);
    await AuthService.instance.clearPin();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const FamilySetupScreen()),
    );
  }

  void _shake(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _error = message;
      _pin = '';
    });
  }

  // ─── UI ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.fromSettings)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    const SizedBox(width: 40),
                  if (!widget.fromSettings && !_verifyingOld)
                    TextButton(
                      onPressed: _skip,
                      child: const Text('Skip for now'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.lock, color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              _title,
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray,
                ),
              ),
            ),
            const SizedBox(height: 26),
            _PinDots(filled: _pin.length, error: _error != null)
                .animate(target: _error != null ? 1 : 0)
                .shakeX(hz: 4, amount: 6, duration: 320.ms),
            const SizedBox(height: 14),
            SizedBox(
              height: 22,
              child: _error == null
                  ? const SizedBox.shrink()
                  : Text(
                      _error!,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
            ),
            const Spacer(),
            _NumPad(onDigit: _onDigit, onBackspace: _onBackspace),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.filled, required this.error});

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
                  ? (error ? AppColors.danger : AppColors.primary)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: error
                    ? AppColors.danger
                    : AppColors.primary.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
      ],
    );
  }
}

class _NumPad extends StatelessWidget {
  const _NumPad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
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
          if (k.isEmpty) return const SizedBox.shrink();
          if (k == '⌫') {
            return _Key(
              child: const Icon(Icons.backspace_outlined),
              onTap: onBackspace,
            );
          }
          return _Key(
            child: Text(
              k,
              style: GoogleFonts.nunito(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            onTap: () => onDigit(k),
          );
        },
      ),
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
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.gray.withValues(alpha: 0.18),
            ),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
