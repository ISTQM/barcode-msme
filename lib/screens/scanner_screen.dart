import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../cubit/inventory_cubit.dart';
import '../widgets/item_sheet.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, required this.active});

  /// False while another tab is showing, so the camera can be released.
  final bool active;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
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

  static const Duration _rescanCooldown = Duration(seconds: 2);

  bool _sheetOpen = false;
  String? _lastBarcode;
  DateTime? _lastClosedAt;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_sheetOpen || !widget.active) return;

    String? barcode;
    for (final candidate in capture.barcodes) {
      final value = candidate.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        barcode = value;
        break;
      }
    }
    if (barcode == null) return;

    // The camera is still pointing at the item that was just saved.
    final closedAt = _lastClosedAt;
    if (barcode == _lastBarcode &&
        closedAt != null &&
        DateTime.now().difference(closedAt) < _rescanCooldown) {
      return;
    }

    _sheetOpen = true;
    HapticFeedback.mediumImpact();
    await showItemSheet(
      context,
      cubit: context.read<InventoryCubit>(),
      barcode: barcode,
    );
    _lastBarcode = barcode;
    _lastClosedAt = DateTime.now();
    _sheetOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
