import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/onboarding_service.dart';
import '../utils/app_colors.dart';
import 'pin_setup_screen.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, this.fromSettings = false});

  final bool fromSettings;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _pageController = PageController();
  int _index = 0;

  static const _slides = [
    _Slide(
      headline: "Where's your Aadhaar copy? 😅",
      body:
          'Scattered across WhatsApp chats, Gmail, Drive, random folders. Always missing when you need it most.',
      subtext: 'DocShelf fixes that — forever.',
      illustration: _IllustrationKind.messy,
    ),
    _Slide(
      headline: 'One vault. Every document. 🗂️',
      body:
          'Identity, Finance, Health, Property, Vehicle, Education — organized the way Indian families actually need it.',
      subtext: 'Works with PDFs, images, scans, photos.',
      illustration: _IllustrationKind.categories,
    ),
    _Slide(
      headline: 'For your whole family 👨‍👩‍👧',
      body:
          'Self, spouse, kids, parents — separate document trees per person. Tap any avatar to switch profiles instantly.',
      subtext: 'All offline. All on your device.',
      illustration: _IllustrationKind.family,
    ),
    _Slide(
      headline: 'Bank-grade lock. Zero cloud. 🔐',
      body:
          'Biometric + PIN. Files stay on YOUR device. No upload, no tracking, no ads. We don\'t even have your data.',
      subtext: '',
      illustration: _IllustrationKind.shield,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingService.instance.markTutorialSeen();
    if (!mounted) return;
    if (widget.fromSettings) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _slides.length - 1;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_index + 1} / ${_slides.length}',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white.withValues(alpha: 0.7),
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (!last)
                      TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor:
                              AppColors.white.withValues(alpha: 0.85),
                        ),
                        child: const Text('Skip'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
                ),
              ),
              _Dots(count: _slides.length, active: _index),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Row(
                  children: [
                    if (_index > 0)
                      OutlinedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.white,
                          side: BorderSide(
                            color: AppColors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text('Back'),
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () {
                        if (last) {
                          _finish();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                      child: Text(
                        last ? 'Set Up DocShelf →' : 'Next',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Internals ───────────────────────────────────────────────────────
enum _IllustrationKind { messy, categories, family, shield }

class _Slide {
  const _Slide({
    required this.headline,
    required this.body,
    required this.subtext,
    required this.illustration,
  });

  final String headline;
  final String body;
  final String subtext;
  final _IllustrationKind illustration;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Expanded(
            flex: 5,
            child: Center(
              child: _Illustration(kind: slide.illustration),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  slide.headline,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.white,
                    height: 1.2,
                  ),
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 14),
                Text(
                  slide.body,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.white.withValues(alpha: 0.9),
                    height: 1.45,
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                if (slide.subtext.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    slide.subtext,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      letterSpacing: 0.3,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.kind});
  final _IllustrationKind kind;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _IllustrationKind.messy:
        return _MessyIllustration();
      case _IllustrationKind.categories:
        return _CategoriesIllustration();
      case _IllustrationKind.family:
        return _FamilyIllustration();
      case _IllustrationKind.shield:
        return _ShieldIllustration();
    }
  }
}

class _MessyIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final docs = ['🪪', '📄', '🧾', '📘', '🛡️'];
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 18,
        children: [
          for (var i = 0; i < docs.length; i++)
            Transform.rotate(
              angle: (i.isEven ? -0.18 : 0.18) * (i + 1) / docs.length,
              child: _DocChip(emoji: docs[i])
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(
                    begin: 0,
                    end: -6,
                    duration: 1200.ms + (i * 100).ms,
                    curve: Curves.easeInOut,
                  ),
            ),
        ],
      ),
    );
  }
}

class _CategoriesIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cats = [
      ('🪪', 'Identity'),
      ('💰', 'Finance'),
      ('🏥', 'Health'),
      ('🚗', 'Vehicle'),
      ('🎓', 'Education'),
      ('🏠', 'Property'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < cats.length; i++)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cats[i].$1, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    cats[i].$2,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: (i * 100).ms, duration: 300.ms).moveY(
                  begin: 16,
                  end: 0,
                  delay: (i * 100).ms,
                  duration: 300.ms,
                  curve: Curves.easeOutCubic,
                ),
        ],
      ),
    );
  }
}

class _FamilyIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ppl = [
      ('👨', 'Self'),
      ('👩', 'Wife'),
      ('👦', 'Son'),
      ('👴', 'Dad'),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        for (var i = 0; i < ppl.length; i++)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.55),
                    width: 2,
                  ),
                ),
                child: Text(ppl[i].$1, style: const TextStyle(fontSize: 36)),
              ),
              const SizedBox(height: 8),
              Text(
                ppl[i].$2,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
            ],
          )
              .animate()
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                delay: (i * 120).ms,
                duration: 320.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(delay: (i * 120).ms, duration: 240.ms),
      ],
    );
  }
}

class _ShieldIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pillars = ['No ads', 'No tracking', 'Biometric', 'Offline'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 132,
          height: 132,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.6),
              width: 3,
            ),
          ),
          child: const Text('🔐', style: TextStyle(fontSize: 64)),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < pillars.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '✓ ${pillars[i]}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
              ).animate().fadeIn(delay: (250 + i * 100).ms, duration: 240.ms),
          ],
        ),
      ],
    );
  }
}

class _DocChip extends StatelessWidget {
  const _DocChip({required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 32)),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active
                  ? AppColors.accent
                  : AppColors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
