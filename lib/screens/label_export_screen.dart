import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/brand_config.dart';
import '../core/label_geometry.dart';
import '../core/sheet_layout.dart';
import '../cubit/barcode_cubit.dart';
import '../cubit/inventory_cubit.dart';
import '../data/label_job.dart';
import '../data/product_barcode.dart';
import '../services/label_export_service.dart';
import '../widgets/barcode_tile.dart';
import '../widgets/barcode_ui.dart';
import '../widgets/micro_animations.dart';

enum _SizeChoice {
  small('Small', LabelSize.small),
  medium('Medium', LabelSize.medium),
  large('Large', LabelSize.large),
  custom('Custom', null);

  const _SizeChoice(this.label, this.size);

  final String label;
  final LabelSize? size;
}

/// Print and export options for one barcode: label style and size, paper,
/// number of copies, and PDF, DOCX or a plain image.
class LabelExportScreen extends StatefulWidget {
  const LabelExportScreen({
    super.key,
    required this.barcode,
    this.justCreated = false,
  });

  final String barcode;

  /// True right after saving, which adds a short confirmation at the top.
  final bool justCreated;

  @override
  State<LabelExportScreen> createState() => _LabelExportScreenState();
}

class _LabelExportScreenState extends State<LabelExportScreen> {
  final LabelExportService _service = LabelExportService();
  final GlobalKey _sheetButtonKey = GlobalKey();
  final GlobalKey _imageButtonKey = GlobalKey();

  late final ProductBarcode _product;
  final TextEditingController _copiesField = TextEditingController(text: '24');
  final TextEditingController _customWidth = TextEditingController(text: '50');
  final TextEditingController _customHeight = TextEditingController(text: '30');

  late LabelStyle _style;
  _SizeChoice _sizeChoice = _SizeChoice.medium;
  PaperSize _paper = PaperSize.a4;
  SheetFormat _format = SheetFormat.pdf;
  int _copies = 24;
  bool _cutGuides = true;
  bool _busySheet = false;
  bool _busyImage = false;

  @override
  void initState() {
    super.initState();
    _product = context.read<BarcodeCubit>().find(widget.barcode)!;
    _style = _product.style;
  }

  @override
  void dispose() {
    _copiesField.dispose();
    _customWidth.dispose();
    _customHeight.dispose();
    super.dispose();
  }

  /// Null while a custom size is blank, not a number, or outside the range
  /// that fits a label.
  LabelSize? get _size {
    final preset = _sizeChoice.size;
    if (preset != null) return preset;
    final width = double.tryParse(_customWidth.text);
    final height = double.tryParse(_customHeight.text);
    if (width == null || height == null) return null;
    if (width < LabelSize.minWidthMm || width > LabelSize.maxWidthMm) {
      return null;
    }
    if (height < LabelSize.minHeightMm || height > LabelSize.maxHeightMm) {
      return null;
    }
    return LabelSize(width, height);
  }

  LabelJob? get _job {
    final size = _size;
    if (size == null) return null;
    return LabelJob(
      content: _product.content,
      style: _style,
      size: size,
      paper: _paper,
      copies: _copies,
      cutGuides: _cutGuides,
    );
  }

  bool get _canExportSheet {
    final job = _job;
    return job != null && job.layout.fits && !_busySheet && !_busyImage;
  }

  void _setCopies(int value) {
    final next = value.clamp(1, LabelJob.maxCopies);
    setState(() {
      _copies = next;
      _copiesField.text = '$next';
    });
  }

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _run({
    required Future<File> Function() build,
    required String mime,
    required GlobalKey buttonKey,
    required void Function(bool busy) setBusy,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => setBusy(true));
    try {
      final file = await build();
      await _service.share(file, mime: mime, origin: _rectOf(buttonKey));
    } on Object {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Export failed. Try again.')),
        );
    } finally {
      if (mounted) setState(() => setBusy(false));
    }
  }

  Future<void> _exportSheet() async {
    final job = _job;
    if (job == null || !_canExportSheet) return;
    await _run(
      build: () => _format == SheetFormat.pdf
          ? _service.createPdf(job)
          : _service.createDocx(job),
      mime: _format.mime,
      buttonKey: _sheetButtonKey,
      setBusy: (busy) => _busySheet = busy,
    );
  }

  Future<void> _exportImage() async {
    if (_busySheet || _busyImage) return;
    await _run(
      build: () => _service.createImage(_product.content),
      mime: 'image/png',
      buttonKey: _imageButtonKey,
      setBusy: (busy) => _busyImage = busy,
    );
  }

  Future<void> _addToInventory() async {
    final messenger = ScaffoldMessenger.of(context);
    await context.read<InventoryCubit>().save(
          barcode: _product.barcode,
          name: _product.name,
          quantity: 0,
          priceCentavos: _product.priceCentavos,
        );
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('${_product.name} added to inventory')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
    final ink = isDark ? Colors.white : const Color(0xFF09090B);
    final job = _job;
    final geometry = job?.geometry;
    final layout = job?.layout;
    final inInventory =
        context.read<InventoryCubit>().find(_product.barcode) != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Print & Export')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (widget.justCreated) ...[
            _Banner(
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF22C55E),
              text: inInventory
                  ? 'Barcode saved and added to inventory with 0 in stock.'
                  : 'Barcode saved.',
            ),
            const SizedBox(height: 16),
          ],
          Panel(
            child: Row(
              children: [
                ProductThumb(
                  file: context.read<BarcodeCubit>().photoOf(_product),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_product.symbology.label} · ${_product.barcode}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!inInventory && !widget.justCreated) ...[
            const SizedBox(height: 12),
            _Banner(
              icon: Icons.inventory_2_outlined,
              iconColor: ink,
              text: 'Not in inventory yet.',
              action: 'Add',
              onAction: () async {
                await _addToInventory();
                if (mounted) setState(() {});
              },
            ),
          ],
          const SizedBox(height: 24),
          const SectionLabel('Label style'),
          SleekSegmentedControl<LabelStyle>(
            items: {for (final style in LabelStyle.values) style: style.label},
            selected: _style,
            onChanged: (style) => setState(() => _style = style),
          ),
          const SizedBox(height: 16),
          Panel(
            child: Column(
              children: [
                if (geometry != null)
                  LabelPreview(geometry: geometry)
                else
                  SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        'Enter a valid label size to see the preview.',
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  geometry == null
                      ? 'Preview'
                      : 'Preview · ${job!.size.text}',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                if (geometry != null && !geometry.scansReliably) ...[
                  const SizedBox(height: 12),
                  const _Banner(
                    icon: Icons.warning_amber_rounded,
                    iconColor: Color(0xFFF59E0B),
                    text: 'The bars are very small at this size and may not '
                        'scan reliably. Pick a larger label.',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Label size'),
          SleekSegmentedControl<_SizeChoice>(
            items: {
              for (final choice in _SizeChoice.values) choice: choice.label,
            },
            selected: _sizeChoice,
            onChanged: (choice) => setState(() => _sizeChoice = choice),
          ),
          const SizedBox(height: 8),
          if (_sizeChoice == _SizeChoice.custom)
            Row(
              children: [
                Expanded(
                  child: _MillimetreField(
                    controller: _customWidth,
                    label: 'Width (mm)',
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MillimetreField(
                    controller: _customHeight,
                    label: 'Height (mm)',
                    onChanged: () => setState(() {}),
                  ),
                ),
              ],
            )
          else
            Text(
              _sizeChoice.size!.text,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          if (_sizeChoice == _SizeChoice.custom && _size == null) ...[
            const SizedBox(height: 8),
            Text(
              'Width ${LabelSize.minWidthMm.round()}–${LabelSize.maxWidthMm.round()} mm, '
              'height ${LabelSize.minHeightMm.round()}–${LabelSize.maxHeightMm.round()} mm.',
              style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
            ),
          ],
          const SizedBox(height: 24),
          const SectionLabel('Paper size'),
          SleekSegmentedControl<PaperSize>(
            items: {for (final paper in PaperSize.values) paper: paper.label},
            selected: _paper,
            onChanged: (paper) => setState(() => _paper = paper),
          ),
          const SizedBox(height: 8),
          Text(
            _paper.dimensions,
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Copies'),
          Row(
            children: [
              TapScale(
                child: IconButton.filledTonal(
                  onPressed: () => _setCopies(_copies - 1),
                  icon: const Icon(Icons.remove),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _copiesField,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration:
                      const InputDecoration(labelText: 'Number of labels'),
                  onChanged: (text) {
                    final parsed = int.tryParse(text);
                    if (parsed != null) {
                      setState(
                        () => _copies = parsed.clamp(1, LabelJob.maxCopies),
                      );
                    }
                  },
                  onEditingComplete: () {
                    _setCopies(_copies);
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),
              const SizedBox(width: 12),
              TapScale(
                child: IconButton.filledTonal(
                  onPressed: () => _setCopies(_copies + 1),
                  icon: const Icon(Icons.add),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (layout != null)
            Text(
              layout.fits
                  ? '${layout.perPage} per page · '
                      '${layout.pages} ${layout.pages == 1 ? 'page' : 'pages'}'
                  : 'This label is larger than the page. Pick a smaller '
                      'label or bigger paper.',
              style: TextStyle(
                fontSize: 12,
                color: layout.fits ? muted : const Color(0xFFEF4444),
              ),
            ),
          const SizedBox(height: 16),
          Panel(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cut guides',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'A thin grey border around each label to cut along.',
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _cutGuides,
                  onChanged: (value) => setState(() => _cutGuides = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('File type'),
          SleekSegmentedControl<SheetFormat>(
            items: {for (final format in SheetFormat.values) format: format.label},
            selected: _format,
            onChanged: (format) => setState(() => _format = format),
          ),
          const SizedBox(height: 20),
          TapScale(
            child: FilledButton.icon(
              key: _sheetButtonKey,
              onPressed: _canExportSheet ? _exportSheet : null,
              style: primaryButtonStyle(context, height: 60),
              icon: _busySheet
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    )
                  : const Icon(Icons.print_outlined, size: 20),
              label: Text(
                'Print / Export ${_format.label}',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TapScale(
            child: OutlinedButton.icon(
              key: _imageButtonKey,
              onPressed: _busySheet || _busyImage ? null : _exportImage,
              style: OutlinedButton.styleFrom(
                foregroundColor: ink,
                minimumSize: const Size.fromHeight(54),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF3F3F46)
                      : const Color(0xFFD4D4D8),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BrandScope.of(context).cornerStyle.mediumRadius,
                ),
              ),
              icon: _busyImage
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: ink,
                      ),
                    )
                  : const Icon(Icons.image_outlined, size: 20),
              label: const Text(
                'Export Barcode Image (PNG)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 14, color: muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Made on your phone. Print, save to Files, or send by Viber.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MillimetreField extends StatelessWidget {
  const _MillimetreField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,1})?$')),
      ],
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => onChanged(),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brand = BrandScope.of(context);
    final ink = isDark ? Colors.white : const Color(0xFF09090B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF4F4F5),
        borderRadius: brand.cornerStyle.smallRadius,
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                action!,
                style: TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
            ),
        ],
      ),
    );
  }
}
