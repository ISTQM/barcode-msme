import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/brand_config.dart';
import '../core/scan_gate.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/receipt_cubit.dart';
import '../cubit/receipt_state.dart';
import '../services/scan_feedback.dart';
import '../widgets/item_sheet.dart';
import '../widgets/micro_animations.dart';
import '../widgets/push_to_scan_trigger.dart';
import '../widgets/receipt_scan_panel.dart';
import '../widgets/viewfinder.dart';
import 'receipt_screen.dart';

/// Cashier checkout session ("Counter").
/// Customer items are scanned one by one to assemble a customer receipt.
/// Includes toggleable Push-to-Scan safety feature (enabled by default) to prevent accidental scanning.
class CounterScreen extends StatefulWidget {
  const CounterScreen({
    super.key,
    required this.active,
  });

  /// False when another tab is showing, so the camera is released.
  final bool active;

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen>
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
  ReceiptScanResult? _last;
  bool _sheetOpen = false;

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
    // Inherit default push to scan setting from white-label brand configuration.
    final brand = BrandScope.of(context);
    _pushToScan = brand.defaultPushToScan;
    _isArmed = !_pushToScan;
  }

  @override
  void didUpdateWidget(CounterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      widget.active ? _startCamera() : _controller.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.active) return;
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
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startCamera() async {
    try {
      await _controller.start();
    } on MobileScannerException {
      // Handled via controller state and CameraErrorView.
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!widget.active || _sheetOpen) return;

    // Safety check: block accidental scans when push-to-scan is active and not armed.
    if (_pushToScan && !_isArmed) return;

    String? fresh;
    for (final candidate in capture.barcodes) {
      final value = candidate.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      if (_gate.accept(value) && fresh == null) fresh = value;
    }
    if (fresh == null) return;

    // One scan at a time: immediately disarm after a successful detection.
    if (_pushToScan) {
      setState(() => _isArmed = false);
    }

    final item = context.read<InventoryCubit>().find(fresh);
    final feedback = context.read<ScanFeedback>();

    if (item == null) {
      feedback.play(ScanTone.unknown);
      setState(() => _last = ReceiptScanResult.unknown(fresh!));
      return;
    }

    context.read<ReceiptCubit>().addItem(item);
    feedback.play(ScanTone.scanned);
    setState(() => _last = ReceiptScanResult.added(fresh!));
  }

  Future<void> _addUnknownToInventory(String barcode) async {
    final inventory = context.read<InventoryCubit>();

    _sheetOpen = true;
    _controller.stop();
    final saved = await showItemSheet(
      context,
      cubit: inventory,
      barcode: barcode,
      scanned: true,
    );
    _sheetOpen = false;

    if (mounted && widget.active) {
      _startCamera();
    }

    final item = inventory.find(barcode);
    if (!saved || item == null || !mounted) return;

    context.read<ReceiptCubit>().addItem(item);
    setState(() => _last = ReceiptScanResult.added(barcode));
  }

  Future<void> _reviewReceipt() async {
    _controller.stop();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReceiptScreen()),
    );
    if (mounted && widget.active) {
      _startCamera();
    }
  }

  void _toggleSafetyMode() {
    HapticFeedback.selectionClick();
    final next = !_pushToScan;
    setState(() {
      _pushToScan = next;
      _isArmed = !next; // Auto mode is always armed
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

  Future<void> _confirmClearCart() async {
    final cubit = context.read<ReceiptCubit>();
    if (cubit.state.lines.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Order?'),
        content: const Text(
          'This will remove all scanned items for the current customer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      cubit.clear();
      setState(() => _last = null);
    }
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
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: brand.cornerStyle.smallRadius,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.point_of_sale_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Counter',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          BlocBuilder<ReceiptCubit, ReceiptState>(
                            builder: (context, state) {
                              final count = state.lines.length;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: count > 0
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  count > 0 ? '$count items' : 'Ready',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: count > 0
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    BlocBuilder<ReceiptCubit, ReceiptState>(
                      builder: (context, state) {
                        if (state.lines.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TapScale(
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
                                onPressed: _confirmClearCart,
                                tooltip: 'Clear current cart',
                                icon: const Icon(
                                  Icons.delete_sweep_outlined,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_pushToScan) ...[
                  PushToScanTrigger(
                    isArmed: _isArmed,
                    onArmedChanged: (val) => setState(() => _isArmed = val),
                  ),
                  const SizedBox(height: 12),
                ],
                ReceiptScanPanel(
                  last: _last,
                  onAddUnknown: _addUnknownToInventory,
                  onReview: _reviewReceipt,
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
