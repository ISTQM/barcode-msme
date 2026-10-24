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
/// Features a glowing radial canvas, expanding ripple, animated circular
/// progress ring, bouncy logo entrance, and fluid transition to the home shell.
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
    final disc = (size.shortestSide * 0.36).clamp(120.0, 156.0);

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
                  center: Alignment(0, -0.15),
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
                    Align(
                      alignment: const Alignment(0, -0.12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: disc + 72,
                              height: disc + 72,
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
                                      scale: 0.78 + 0.22 * logoIn,
                                      child: _BrandDisc(
                                        size: disc,
                                        cornerStyle: brand.cornerStyle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // App Name
                            Opacity(
                              opacity: title.clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, 16 * (1 - title)),
                                child: Text(
                                  brand.appName,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Tagline
                            Opacity(
                              opacity: tagline.clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, 10 * (1 - tagline)),
                                child: Text(
                                  brand.tagline,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                    color: Colors.white.withValues(alpha: 0.65),
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
                      bottom: math.max(28.0, inset.bottom + 20),
                      child: Opacity(
                        opacity: footer.clamp(0.0, 1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              brand.organization,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.8,
                                color: Colors.white.withValues(alpha: 0.60),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              brand.footerNote,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                                color: Colors.white.withValues(alpha: 0.38),
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

/// Logo disc container with tactile border and scanner iconography.
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
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: size * 0.44,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'MSME',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
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
    final glowRadius = discRadius * 2.1;
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.18 * glow),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );

    // Expanding Ripple
    if (ripple > 0 && ripple < 1) {
      final r = discRadius + 14 + (discRadius * 0.85) * ripple;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: 0.28 * (1 - ripple)),
      );
    }

    // Progress Track and Arc
    final ringRadius = discRadius + 14;
    final rect = Rect.fromCircle(center: center, radius: ringRadius);

    // Faint track
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
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
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.90),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.glow != glow || old.ripple != ripple || old.progress != progress;
}
