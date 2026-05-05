import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/onboarding_service.dart';
import '../utils/app_colors.dart';
import 'main_shell.dart';
import 'tutorial_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final ob = OnboardingService.instance;
    if (!await ob.hasSeenTutorial()) {
      _go(const TutorialScreen());
      return;
    }
    _go(const MainShell());
  }

  void _go(Widget page) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ─── Doc (line 1) ─────────────────────────────────
                    Text(
                      'Doc',
                      style: GoogleFonts.nunito(
                        fontSize: 88,
                        fontWeight: FontWeight.w900,
                        color: AppColors.white,
                        height: 1,
                        letterSpacing: -2,
                      ),
                    )
                        .animate()
                        .slideY(
                          begin: -0.4,
                          end: 0,
                          duration: 420.ms,
                          curve: Curves.easeOutCubic,
                        )
                        .fadeIn(duration: 420.ms),
                    const SizedBox(height: 4),
                    // ─── Shelf (line 2) ───────────────────────────────
                    Text(
                      'Shelf',
                      style: GoogleFonts.nunito(
                        fontSize: 88,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accent,
                        height: 1,
                        letterSpacing: -2,
                      ),
                    )
                        .animate()
                        .slideY(
                          begin: 0.4,
                          end: 0,
                          delay: 200.ms,
                          duration: 420.ms,
                          curve: Curves.easeOutCubic,
                        )
                        .fadeIn(delay: 200.ms, duration: 420.ms),
                    const SizedBox(height: 18),
                    // ─── Subtle shelf accent line ─────────────────────
                    Container(
                      width: 160,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                        .animate()
                        .scaleX(
                          begin: 0,
                          end: 1,
                          delay: 700.ms,
                          duration: 240.ms,
                          curve: Curves.easeOutCubic,
                        )
                        .fadeIn(delay: 700.ms, duration: 240.ms),
                    const SizedBox(height: 14),
                    // ─── Tagline (line 3) ─────────────────────────────
                    Text(
                      'FILES ORGANIZED · OFFLINE',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4.0,
                        color: AppColors.white.withValues(alpha: 0.78),
                      ),
                    ).animate().fadeIn(delay: 950.ms, duration: 260.ms),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 32,
                child: Center(
                  child: Text(
                    '🗂️ Local-first  •  No cloud  •  No ads',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white.withValues(alpha: 0.65),
                      letterSpacing: 0.4,
                    ),
                  ).animate().fadeIn(delay: 1200.ms, duration: 300.ms),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
