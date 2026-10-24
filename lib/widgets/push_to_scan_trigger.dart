import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/brand_config.dart';

/// Tactile "Push to Scan" safety trigger button.
///
/// Prevents accidental barcode scanning by ensuring the camera only decodes
/// when the cashier actively pushes/holds this trigger.
class PushToScanTrigger extends StatefulWidget {
  const PushToScanTrigger({
    super.key,
    required this.isArmed,
    required this.onArmedChanged,
  });

  final bool isArmed;
  final ValueChanged<bool> onArmedChanged;

  @override
  State<PushToScanTrigger> createState() => _PushToScanTriggerState();
}

class _PushToScanTriggerState extends State<PushToScanTrigger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  Timer? _tapWindowTimer;
  DateTime? _pointerDownTime;
  bool _isHolding = false;

  @override
  void dispose() {
    _tapWindowTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownTime = DateTime.now();
    _isHolding = true;
    _tapWindowTimer?.cancel();
    HapticFeedback.lightImpact();
    widget.onArmedChanged(true);
    _pulseController.repeat(reverse: true);
  }

  void _onPointerUp(PointerUpEvent event) {
    _pulseController.stop();
    _pulseController.reset();

    final downTime = _pointerDownTime;
    final heldDuration = downTime != null
        ? DateTime.now().difference(downTime)
        : const Duration(milliseconds: 500);

    _isHolding = false;

    // If released quickly (< 300ms tap), keep armed for a 2.5s window
    // so the user can easily single-tap to scan without holding their thumb down.
    if (heldDuration.inMilliseconds < 300 && widget.isArmed) {
      HapticFeedback.selectionClick();
      _tapWindowTimer?.cancel();
      _tapWindowTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted && !_isHolding) {
          widget.onArmedChanged(false);
        }
      });
    } else {
      HapticFeedback.selectionClick();
      widget.onArmedChanged(false);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _isHolding = false;
    _pulseController.stop();
    _pulseController.reset();
    _tapWindowTimer?.cancel();
    widget.onArmedChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final brand = BrandScope.of(context);
    final armed = widget.isArmed;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedScale(
        scale: armed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: armed ? Colors.white : Colors.black.withValues(alpha: 0.78),
            borderRadius: brand.cornerStyle.mediumRadius,
            border: Border.all(
              color: armed
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.28),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: armed
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.45),
                blurRadius: armed ? 16 : 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                armed ? Icons.qr_code_scanner : Icons.touch_app_rounded,
                size: 20,
                color: armed ? Colors.black : Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                armed ? 'SCANNING...' : 'PUSH TO SCAN',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: armed ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
