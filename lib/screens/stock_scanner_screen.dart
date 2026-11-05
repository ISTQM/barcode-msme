import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/brand_config.dart';
import '../core/scan_gate.dart';
import '../cubit/inventory_cubit.dart';
import '../services/scan_feedback.dart';
import '../widgets/item_sheet.dart';
import '../widgets/micro_animations.dart';
import '../widgets/push_to_scan_trigger.dart';
import '../widgets/viewfinder.dart';

/// Dedicated camera scanner for isolated inventory intake and restocking.
/// Includes toggleable Push-to-Scan safety feature (enabled by default) to prevent accidental scanning.
class StockScannerScreen extends StatefulWidget {
  const StockScannerScreen({super.key});

  @override
  State<StockScannerScreen> createState() => _StockScannerScreenState();
}

class _StockScannerScreenState extends State<StockScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.itf14,
      BarcodeFormat.codabar,
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
    ],
  );

  final ScanGate _gate = ScanGate();
  bool _sheetOpen = false;
  String? _recentNotice;
  Timer? _noticeTimer;

  /// Safety feature: enabled by default to prevent accidental scans.
  bool _pushToScan = true;

  /// True when the user is actively pushing/holding the trigger, or in auto-scan mode.
  bool _isArmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brand = BrandScope.of(context);
    _pushToScan = brand.defaultPushToScan;
    _isArmed = !_pushToScan;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startCamera();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startCamera() async {
    try {
      await _controller.start();
    } on MobileScannerException {
      // Surfaced by controller state and error view.
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_sheetOpen) return;
    if (_pushToScan && !_isArmed) return;

    String? fresh;
    for (final candidate in capture.barcodes) {
      final value = candidate.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      if (_gate.accept(value) && fresh == null) fresh = value;
    }
    if (fresh == null || _sheetOpen) return;

    if (_pushToScan) {
      setState(() => _isArmed = false);
    }

    final cubit = context.read<InventoryCubit>();
    final known = cubit.find(fresh) != null;

    _sheetOpen = true;
    context.read<ScanFeedback>().play(
      known ? ScanTone.duplicate : ScanTone.scanned,
    );

    final saved = await showItemSheet(
      context,
      cubit: cubit,
      barcode: fresh,
      scanned: true,
    );
    _sheetOpen = false;

    if (saved && mounted) {
      final item = cubit.find(fresh);
      final label = item != null
          ? 'Saved ${item.name} (${item.quantity} in stock)'
          : 'Stock updated';
      setState(() => _recentNotice = label);
      _noticeTimer?.cancel();
      _noticeTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _recentNotice = null);
      });
    }
  }

  void _toggleSafetyMode() {
    HapticFeedback.selectionClick();
    final next = !_pushToScan;
    setState(() {
      _pushToScan = next;
      _isArmed = !next;
    });
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            next
                ? 'Push to Scan enabled (Accidental scans prevented)'
                : 'Auto-Scan enabled (Continuous scanning)',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final brand = BrandScope.of(context);
    final isScanningArmed = !_pushToScan || _isArmed;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) =>
                CameraErrorView(error: error, onRetry: _startCamera),
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) => state.error == null
                ? Viewfinder(
                    isArmed: isScanningArmed,
                    pushToScan: _pushToScan,
                  )
                : const SizedBox.shrink(),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      TapScale(
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Stock Intake',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              _pushToScan
                                  ? 'Push trigger to scan stock'
                                  : 'Auto-scanning catalog barcodes',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _SafetyToggleButton(
                        pushToScan: _pushToScan,
                        onPressed: _toggleSafetyMode,
                      ),
                      const SizedBox(width: 8),
                      _TorchButton(controller: _controller),
                    ],
                  ),
                ),
                const Spacer(),
                if (_pushToScan) ...[
                  PushToScanTrigger(
                    isArmed: _isArmed,
                    onArmedChanged: (val) => setState(() => _isArmed = val),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_recentNotice != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: brand.cornerStyle.mediumRadius,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF22C55E),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _recentNotice!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyToggleButton extends StatelessWidget {
  const _SafetyToggleButton({
    required this.pushToScan,
    required this.onPressed,
  });

  final bool pushToScan;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: pushToScan
              ? Colors.white
              : Colors.black.withValues(alpha: 0.65),
          shape: BoxShape.circle,
          border: Border.all(
            color: pushToScan
                ? Colors.white
                : Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          tooltip: pushToScan
              ? 'Push-to-Scan ON (Tap for Auto-Scan)'
              : 'Auto-Scan ON (Tap for Push-to-Scan Safety)',
          icon: Icon(
            pushToScan ? Icons.touch_app_rounded : Icons.flash_auto_rounded,
            size: 20,
            color: pushToScan ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        if (state.torchState == TorchState.unavailable) {
          return const SizedBox(width: 42, height: 42);
        }
        final on = state.torchState == TorchState.on;
        return TapScale(
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: on ? Colors.white : Colors.black.withValues(alpha: 0.65),
              shape: BoxShape.circle,
              border: Border.all(
                color: on
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: controller.toggleTorch,
              tooltip: 'Flashlight',
              icon: Icon(
                on ? Icons.flash_on : Icons.flash_off,
                size: 20,
                color: on ? Colors.black : Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}
