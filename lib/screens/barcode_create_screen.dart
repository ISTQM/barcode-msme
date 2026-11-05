import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../core/barcode_codec.dart';
import '../core/brand_config.dart';
import '../core/label_geometry.dart';
import '../core/money.dart';
import '../core/sheet_layout.dart';
import '../cubit/barcode_cubit.dart';
import '../cubit/inventory_cubit.dart';
import '../data/product_barcode.dart';
import '../services/photo_service.dart';
import '../widgets/barcode_ui.dart';
import '../widgets/micro_animations.dart';
import 'label_export_screen.dart';

/// Makes a barcode for a product: photo, product info, format and number,
/// label style, and whether to register it in inventory straight away.
class BarcodeCreateScreen extends StatefulWidget {
  const BarcodeCreateScreen({super.key});

  @override
  State<BarcodeCreateScreen> createState() => _BarcodeCreateScreenState();
}

class _BarcodeCreateScreenState extends State<BarcodeCreateScreen> {
  static const LabelSize _previewSize = LabelSize.medium;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _details = TextEditingController();
  final TextEditingController _manualCode = TextEditingController();
  final Random _random = Random.secure();

  BarcodeSymbology _symbology = BarcodeSymbology.ean13;
  LabelStyle _style = LabelStyle.withName;
  bool _autoNumber = true;
  bool _addToInventory = true;
  bool _saving = false;
  File? _photo;
  late String _autoCode;

  @override
  void initState() {
    super.initState();
    _autoCode = _freshCode();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _details.dispose();
    _manualCode.dispose();
    super.dispose();
  }

  /// Name of the product already using [code], in inventory or among the
  /// barcodes made here. Null when the number is free.
  String? _takenBy(String code) {
    return context.read<InventoryCubit>().find(code)?.name ??
        context.read<BarcodeCubit>().find(code)?.name;
  }

  String _freshCode() {
    for (var attempt = 0; attempt < 50; attempt++) {
      final code = BarcodeCodec.generate(_symbology, _random);
      if (_takenBy(code) == null) return code;
    }
    // Fifty collisions in a row is not going to happen with 11 random digits.
    return BarcodeCodec.generate(_symbology, _random);
  }

  BarcodeCheck get _check => _autoNumber
      ? BarcodeCheck.ok(_autoCode)
      : BarcodeCodec.check(_symbology, _manualCode.text);

  String? get _takenName {
    final code = _check.code;
    return code == null ? null : _takenBy(code);
  }

  int get _parsedPrice => Money.parse(_price.text) ?? 0;

  bool get _canSave =>
      !_saving &&
      _name.text.trim().isNotEmpty &&
      _check.isValid &&
      _takenName == null;

  /// What the field shows under the number. Nothing until something is typed.
  String? get _numberError {
    if (_autoNumber || _manualCode.text.trim().isEmpty) return null;
    final taken = _takenName;
    if (taken != null) return 'Already used by $taken.';
    return _check.error;
  }

  LabelGeometry? get _previewGeometry {
    final code = _check.code;
    if (code == null) return null;
    final name = _name.text.trim();
    try {
      return LabelGeometry.build(
        LabelContent(
          symbology: _symbology,
          code: code,
          name: name.isEmpty ? 'Product name' : name,
          details: _details.text.trim(),
          priceText:
              _parsedPrice > 0 ? Money.peso(_parsedPrice) : '',
        ),
        _style,
        widthMm: _previewSize.widthMm,
        heightMm: _previewSize.heightMm,
      );
    } on Object {
      return null;
    }
  }

  void _setSymbology(BarcodeSymbology symbology) {
    setState(() {
      _symbology = symbology;
      _manualCode.clear();
      _autoCode = _freshCode();
    });
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await const PhotoService().pick(source);
      if (file != null && mounted) setState(() => _photo = file);
    } on Object {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open the camera or gallery. '
              'Check the permission in Settings.',
            ),
          ),
        );
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final barcodes = context.read<BarcodeCubit>();
    final inventory = context.read<InventoryCubit>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final code = _check.code!;
    final name = _name.text.trim();
    final price = _parsedPrice;

    setState(() => _saving = true);
    try {
      await barcodes.create(
        ProductBarcode(
          barcode: code,
          symbology: _symbology,
          style: _style,
          name: name,
          details: _details.text.trim(),
          priceCentavos: price,
          createdAt: DateTime.now(),
        ),
        photo: _photo,
      );
      if (_addToInventory) {
        await inventory.save(
          barcode: code,
          name: name,
          quantity: 0,
          priceCentavos: price,
        );
      }
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Could not save. Try again.')),
        );
      return;
    }

    HapticFeedback.lightImpact();
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => LabelExportScreen(barcode: code, justCreated: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
    final geometry = _previewGeometry;

    return Scaffold(
      appBar: AppBar(title: const Text('New Barcode')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const SectionLabel('Product photo'),
          _PhotoCard(
            photo: _photo,
            onPick: _pickPhoto,
            onRemove: () => setState(() => _photo = null),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Product info'),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Product name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d{0,7}(\.\d{0,2})?$'),
              ),
            ],
            decoration: InputDecoration(
              labelText: 'Unit price (optional)',
              prefixText: '${BrandScope.of(context).currencySymbol} ',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _details,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Size or variant (optional)',
              hintText: 'e.g. 250 ml',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Barcode format'),
          for (final symbology in BarcodeSymbology.values) ...[
            ChoiceCard(
              title: symbology.label,
              subtitle: symbology.description,
              selected: symbology == _symbology,
              onTap: () => _setSymbology(symbology),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          const SectionLabel('Barcode number'),
          SleekSegmentedControl<bool>(
            items: const {true: 'Auto-generate', false: 'Type my own'},
            selected: _autoNumber,
            onChanged: (auto) => setState(() => _autoNumber = auto),
          ),
          const SizedBox(height: 12),
          if (_autoNumber)
            Panel(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _autoCode,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: isDark ? Colors.white : const Color(0xFF09090B),
                      ),
                    ),
                  ),
                  TapScale(
                    child: IconButton.filledTonal(
                      tooltip: 'New number',
                      onPressed: () =>
                          setState(() => _autoCode = _freshCode()),
                      icon: const Icon(Icons.refresh, size: 20),
                    ),
                  ),
                ],
              ),
            )
          else
            TextField(
              controller: _manualCode,
              keyboardType: _symbology.numericOnly
                  ? TextInputType.number
                  : TextInputType.text,
              inputFormatters: [
                if (_symbology.numericOnly)
                  FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(
                  _symbology.numericOnly
                      ? _symbology.payloadLength + 1
                      : BarcodeCodec.maxCode128Length,
                ),
              ],
              style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Barcode number',
                errorText: _numberError,
                errorMaxLines: 2,
              ),
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: 8),
          Text(
            _autoNumber
                ? (_symbology.numericOnly
                    ? 'Starts with 2, the range reserved for a shop’s own '
                        'products, so it never clashes with a manufacturer’s '
                        'barcode.'
                    : 'A unique code made for this product.')
                : (_symbology.numericOnly
                    ? 'Type ${_symbology.payloadLength} digits and the check '
                        'digit is added, or all ${_symbology.payloadLength + 1}.'
                    : 'Letters, numbers and basic symbols, up to '
                        '${BarcodeCodec.maxCode128Length} characters.'),
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Label style'),
          SleekSegmentedControl<LabelStyle>(
            items: {for (final style in LabelStyle.values) style: style.label},
            selected: _style,
            onChanged: (style) => setState(() => _style = style),
          ),
          const SizedBox(height: 8),
          Text(
            _style == LabelStyle.nameAndPrice && _parsedPrice == 0
                ? 'Add a unit price above to print it on the label.'
                : _style.description,
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 16),
          Panel(
            child: Column(
              children: [
                if (geometry != null)
                  LabelPreview(geometry: geometry)
                else
                  SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        'Enter a valid barcode number to see the label.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Preview · ${_previewSize.text}',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Inventory'),
          Panel(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add to inventory',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color:
                              isDark ? Colors.white : const Color(0xFF09090B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Registers it with 0 in stock, so it is already '
                        'known when you scan it during stock-in.',
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _addToInventory,
                  onChanged: (value) => setState(() => _addToInventory = value),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TapScale(
            child: FilledButton(
              onPressed: _canSave ? _save : null,
              style: primaryButtonStyle(context),
              child: _saving
                  ? SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    )
                  : const Text(
                      'Save & Continue to Print',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.photo,
    required this.onPick,
    required this.onRemove,
  });

  final File? photo;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brand = BrandScope.of(context);
    final muted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
    final borderColor =
        isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

    if (photo == null) {
      return TapScale(
        onTap: onPick,
        scale: 0.98,
        child: Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141416) : Colors.white,
            borderRadius: brand.cornerStyle.mediumRadius,
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF27272A)
                      : const Color(0xFFF4F4F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 26,
                  color: isDark ? Colors.white : const Color(0xFF09090B),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Take a photo of the product',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF09090B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Optional. Helps you recognise it in the list.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: brand.cornerStyle.mediumRadius,
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(photo!, fit: BoxFit.cover, cacheWidth: 1000),
            Positioned(
              right: 10,
              bottom: 10,
              child: Row(
                children: [
                  _PhotoAction(
                    icon: Icons.refresh,
                    label: 'Retake',
                    onTap: onPick,
                  ),
                  const SizedBox(width: 8),
                  _PhotoAction(
                    icon: Icons.delete_outline,
                    label: 'Remove',
                    onTap: onRemove,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoAction extends StatelessWidget {
  const _PhotoAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
