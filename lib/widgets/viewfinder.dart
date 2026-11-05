import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'micro_animations.dart';

/// Corner brackets and an animated laser sweep, drawn over the camera preview.
/// Visual cue with safety status awareness for Push to Scan mode.
class Viewfinder extends StatefulWidget {
  const Viewfinder({
    super.key,
    this.isArmed = true,
    this.pushToScan = false,
  });

  /// True when the scanner is actively decoding barcodes.
  final bool isArmed;

  /// True when push-to-scan safety feature is active.
  final bool pushToScan;

  @override
  State<Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<Viewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweepController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isArmed) {
      _sweepController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(Viewfinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isArmed != oldWidget.isArmed) {
      if (widget.isArmed) {
        _sweepController.repeat(reverse: true);
      } else {
        _sweepController.stop();
      }
    }
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showSweep = widget.isArmed;

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _sweepController,
              builder: (context, _) => CustomPaint(
                painter: _BracketPainter(
                  sweepValue: showSweep ? _sweepController.value : 0.0,
                  isArmed: widget.isArmed,
                  pushToScan: widget.pushToScan,
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.34),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isArmed
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.12),
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
                    widget.pushToScan && !widget.isArmed
                        ? Icons.touch_app_outlined
                        : Icons.center_focus_strong_outlined,
                    size: 15,
                    color: Colors.white.withValues(
                      alpha: widget.isArmed ? 0.95 : 0.65,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.pushToScan
                        ? (widget.isArmed
                            ? 'Scanning barcode...'
                            : 'Push button to scan')
                        : 'Point at a barcode',
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: widget.isArmed ? 1.0 : 0.75,
                      ),
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
  const _BracketPainter({
    required this.sweepValue,
    required this.isArmed,
    required this.pushToScan,
  });

  final double sweepValue;
  final bool isArmed;
  final bool pushToScan;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width * 0.78;
    final frame = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: width,
      height: width * 0.62,
    );
    const arm = 26.0;

    final bracketAlpha = pushToScan && !isArmed ? 0.38 : 1.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: bracketAlpha)
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

    // Subtle laser beam sweeping up and down inside the frame when armed
    if (isArmed) {
      final sweepY = frame.top + frame.height * sweepValue;
      final beamPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(
              alpha: 0.45 * math.sin(sweepValue * math.pi),
            ),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(
          Rect.fromLTRB(
            frame.left + 16,
            sweepY - 1,
            frame.right - 16,
            sweepY + 1,
          ),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;

      canvas.drawLine(
        Offset(frame.left + 14, sweepY),
        Offset(frame.right - 14, sweepY),
        beamPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_BracketPainter oldDelegate) =>
      oldDelegate.sweepValue != sweepValue ||
      oldDelegate.isArmed != isArmed ||
      oldDelegate.pushToScan != pushToScan;
}

/// Shown instead of the preview when the camera cannot start.
class CameraErrorView extends StatelessWidget {
  const CameraErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final MobileScannerException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_off_outlined,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera unavailable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _message(error.errorCode),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            TapScale(
              child: FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _message(MobileScannerErrorCode code) {
    switch (code) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Camera permission was denied. Grant permission in system settings to scan.';
      case MobileScannerErrorCode.unsupported:
        return 'Scanning is not supported on this device.';
      default:
        return 'Could not start the camera. Ensure no other app is using it and retry.';
    }
  }
}
