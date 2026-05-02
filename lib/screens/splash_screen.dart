import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/onboarding_service.dart';
import '../utils/app_colors.dart';
import 'main_shell.dart';
import 'space_setup_screen.dart';
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
    if (!await ob.hasCompletedSpaceSetup()) {
      _go(const SpaceSetupScreen());
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Doc',
                          style: GoogleFonts.nunito(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: AppColors.white,
                            height: 1,
                          ),
                        )
                            .animate()
                            .slideX(
                              begin: -0.6,
                              end: 0,
                              duration: 400.ms,
                              curve: Curves.easeOutCubic,
                            )
                            .fadeIn(duration: 400.ms),
                        Text(
                          'Shelf',
                          style: GoogleFonts.nunito(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accent,
                            height: 1,
                          ),
                        )
                            .animate()
                            .slideX(
                              begin: 0.6,
                              end: 0,
                              delay: 200.ms,
                              duration: 400.ms,
                              curve: Curves.easeOutCubic,
                            )
                            .fadeIn(delay: 200.ms, duration: 400.ms),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: 200,
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
                          duration: 200.ms,
                          curve: Curves.easeOutCubic,
                        )
                        .fadeIn(delay: 700.ms, duration: 200.ms),
                    const SizedBox(height: 14),
                    Text(
                      'YOUR DOCUMENT SHELF',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        color: AppColors.white.withValues(alpha: 0.75),
                      ),
                    ).animate().fadeIn(delay: 900.ms, duration: 200.ms),
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
                  ).animate().fadeIn(delay: 1100.ms, duration: 300.ms),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
