import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Corner brackets and a hint, drawn over the camera preview.
/// Purely visual: the whole preview is scanned, not just the frame.
class Viewfinder extends StatelessWidget {
  const Viewfinder({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BracketPainter())),
          Align(
            alignment: const Alignment(0, 0.32),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Point at a barcode',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width * 0.78;
    final frame = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: width,
      height: width * 0.62,
    );
    const arm = 28.0;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    void corner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin + Offset(dx * arm, 0), paint);
      canvas.drawLine(origin, origin + Offset(0, dy * arm), paint);
    }

    corner(frame.topLeft, 1, 1);
    corner(frame.topRight, -1, 1);
    corner(frame.bottomLeft, 1, -1);
    corner(frame.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
            const Icon(Icons.no_photography_outlined,
                size: 56, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              denied ? 'Camera access is off' : 'Camera unavailable',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              denied
                  ? 'Allow the camera for this app in system settings, '
                      'then try again.'
                  : 'Close other apps using the camera, then try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
