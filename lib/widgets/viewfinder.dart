import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'micro_animations.dart';

/// Corner brackets and an animated laser sweep, drawn over the camera preview.
/// Purely visual: the whole preview is scanned, not just the frame.
class Viewfinder extends StatefulWidget {
  const Viewfinder({super.key});

  @override
  State<Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<Viewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweepController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _sweepController,
              builder: (context, _) => CustomPaint(
                painter: _BracketPainter(sweepValue: _sweepController.value),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.34),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.center_focus_strong_outlined,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Point at a barcode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter({required this.sweepValue});

  final double sweepValue;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width * 0.78;
    final frame = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: width,
      height: width * 0.62,
    );
    const arm = 26.0;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    void corner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin + Offset(dx * arm, 0), paint);
      canvas.drawLine(origin, origin + Offset(0, dy * arm), paint);
    }

    corner(frame.topLeft, 1, 1);
    corner(frame.topRight, -1, 1);
    corner(frame.bottomLeft, 1, -1);
    corner(frame.bottomRight, -1, -1);

    // Subtle laser beam sweeping up and down inside the frame
    final sweepY = frame.top + frame.height * sweepValue;
    final beamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.45 * math.sin(sweepValue * math.pi)),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTRB(frame.left + 16, sweepY - 1, frame.right - 16, sweepY + 1))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawLine(
      Offset(frame.left + 14, sweepY),
      Offset(frame.right - 14, sweepY),
      beamPaint,
    );
  }

  @override
  bool shouldRepaint(_BracketPainter oldDelegate) =>
      oldDelegate.sweepValue != sweepValue;
}

/// Shown instead of the preview when the camera cannot start.
class CameraErrorView extends StatelessWidget {
  const CameraErrorView({super.key, required this.error, required this.onRetry});

  final MobileScannerException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: const Icon(
                Icons.no_photography_outlined,
                size: 40,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              denied ? 'Camera access is required' : 'Camera unavailable',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              denied
                  ? 'Allow camera permissions in settings to scan barcodes.'
                  : 'Close other apps using the camera, then try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            TapScale(
              child: FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(160, 48),
                ),
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
