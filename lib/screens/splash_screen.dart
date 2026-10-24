import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/brand_config.dart';
import 'home_shell.dart';

/// The splash is never shorter than this ...
const Duration _kMinShow = Duration(milliseconds: 650);

/// ... and plays its entrance in this long.
const Duration _kEntrance = Duration(milliseconds: 950);

/// A brief pause on the finished splash before transitioning.
const Duration _kHold = Duration(milliseconds: 180);

/// Beautiful Mobbin-inspired splash screen adapted from msa-app.
/// Features a compact, centered brand mark, ambient radial glow,
/// expanding ripple, circular progress track, and fluid transition to the home shell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.frozenAt});

  /// Shows the entrance stopped at this point (0 to 1) for testing or previews.
  final double? frozenAt;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _kEntrance,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _run();
  }

  Future<void> _run() async {
    final stopwatch = Stopwatch()..start();
    if (!mounted) return;

    if (widget.frozenAt != null) {
      _controller.value = widget.frozenAt!;
      return;
    }

    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1.0;
    } else {
      try {
        await _controller.forward();
      } on TickerCanceled {
        return;
      }
    }

    if (!mounted) return;
    await Future<void>.delayed(_kHold);

    final remaining = _kMinShow - stopwatch.elapsed;
    if (!remaining.isNegative) {
      await Future<void>.delayed(remaining);
    }

    if (!mounted) return;

    // Smooth fade & scale transition to the HomeShell
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          final scale = Tween<double>(begin: 0.98, end: 1.0).animate(fade);
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _t(double a, double b, [Curve curve = Curves.linear]) =>
      Interval(a, b, curve: curve).transform(_controller.value);

  @override
  Widget build(BuildContext context) {
    final brand = BrandScope.of(context);
    final size = MediaQuery.sizeOf(context);
    final inset = MediaQuery.paddingOf(context);
    // Smaller, more refined logo disc with generous breathing room
    final disc = (size.shortestSide * 0.22).clamp(80.0, 94.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Deep OLED black background with subtle radial gradient
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, 0),
                  radius: 1.1,
                  colors: [
                    Color(0xFF18181B),
                    Color(0xFF09090B),
                    Color(0xFF000000),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final logoIn = _t(0.0, 0.52, Curves.easeOutBack);
                final logoFade = _t(0.0, 0.38, Curves.easeOut);
                final title = _t(0.35, 0.72, Curves.easeOutCubic);
                final tagline = _t(0.5, 0.85, Curves.easeOutCubic);
                final footer = _t(0.65, 1.0, Curves.easeOut);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Perfectly centered hero mark
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: disc + 56,
                              height: disc + 56,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Ambient glow, expanding ripple, and progress arc
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _RingsPainter(
                                        discRadius: disc / 2,
                                        glow: _t(0.0, 0.6, Curves.easeOut),
                                        ripple: _t(0.1, 0.95, Curves.easeOut),
                                        progress: _t(
                                          0.15,
                                          0.95,
                                          Curves.easeInOutCubic,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Animated central logo badge
                                  Opacity(
                                    opacity: logoFade.clamp(0.0, 1.0),
                                    child: Transform.scale(
                                      scale: 0.82 + 0.18 * logoIn,
                                      child: _BrandDisc(
                                        size: disc,
                                        cornerStyle: brand.cornerStyle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // App Name
                            Opacity(
                              opacity: title.clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, 14 * (1 - title)),
                                child: Text(
                                  brand.appName,
                                  style: const TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Tagline
                            Opacity(
                              opacity: tagline.clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, 8 * (1 - tagline)),
                                child: Text(
                                  brand.tagline,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.1,
                                    color: Colors.white.withValues(alpha: 0.60),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Bottom Organization & Footer Brand text
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: math.max(28.0, inset.bottom + 18),
                      child: Opacity(
                        opacity: footer.clamp(0.0, 1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              brand.organization,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.8,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              brand.footerNote,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Refined logo disc with generous internal margins and clean scanner emblem.
class _BrandDisc extends StatelessWidget {
  const _BrandDisc({
    required this.size,
    required this.cornerStyle,
  });

  final double size;
  final BrandCornerStyle cornerStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.22),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(size * 0.30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.qr_code_scanner_rounded,
          color: Colors.white,
          size: size * 0.50,
        ),
      ),
    );
  }
}

/// A soft glow behind the logo, one ripple spreading out, and a thin
/// circular arc track that fills up while the app initialises.
class _RingsPainter extends CustomPainter {
  const _RingsPainter({
    required this.discRadius,
    required this.glow,
    required this.ripple,
    required this.progress,
  });

  final double discRadius;
  final double glow;
  final double ripple;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    // Glow
    final glowRadius = discRadius * 2.0;
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.16 * glow),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );

    // Expanding Ripple
    if (ripple > 0 && ripple < 1) {
      final r = discRadius + 12 + (discRadius * 0.8) * ripple;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = Colors.white.withValues(alpha: 0.25 * (1 - ripple)),
      );
    }

    // Progress Track and Arc
    final ringRadius = discRadius + 12;
    final rect = Rect.fromCircle(center: center, radius: ringRadius);

    // Faint track
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = Colors.white.withValues(alpha: 0.12 * math.min(1.0, glow * 2)),
    );

    // Bright filling progress arc
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.92),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) =>
      oldDelegate.glow != glow ||
      oldDelegate.ripple != ripple ||
      oldDelegate.progress != progress;
}
