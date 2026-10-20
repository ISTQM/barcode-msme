import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/scan_gate.dart';
import '../cubit/inventory_cubit.dart';
import '../services/scan_feedback.dart';
import '../widgets/item_sheet.dart';
import '../widgets/viewfinder.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, required this.active});

  /// False while another tab is showing, so the camera can be released.
  final bool active;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  /// Retail formats only. A smaller list keeps detection fast.
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(ScannerScreen oldWidget) {
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
      // Surfaced through the controller state and shown by the error view.
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!widget.active) return;

    // Every sighting is recorded, even while the sheet is open, so a barcode
    // that stays in view after saving is not scanned a second time.
    String? fresh;
    for (final candidate in capture.barcodes) {
      final value = candidate.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      if (_gate.accept(value) && fresh == null) fresh = value;
    }
    if (fresh == null || _sheetOpen) return;

    final cubit = context.read<InventoryCubit>();
    final known = cubit.find(fresh) != null;

    _sheetOpen = true;
    context.read<ScanFeedback>().play(
      known ? ScanTone.duplicate : ScanTone.scanned,
    );
    await showItemSheet(context, cubit: cubit, barcode: fresh);
    _sheetOpen = false;
  }

  @override
  Widget build(BuildContext context) {
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
                ? const Viewfinder()
                : const SizedBox.shrink(),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _TorchButton(controller: _controller),
              ),
            ),
          ),
        ],
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
          return const SizedBox.shrink();
        }
        final on = state.torchState == TorchState.on;
        return IconButton.filled(
          onPressed: controller.toggleTorch,
          style: IconButton.styleFrom(
            backgroundColor: on ? Colors.amber : Colors.black54,
            foregroundColor: on ? Colors.black : Colors.white,
          ),
          tooltip: 'Flashlight',
          icon: Icon(on ? Icons.flash_on : Icons.flash_off),
        );
      },
    );
  }
}
