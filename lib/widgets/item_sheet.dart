import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/brand_config.dart';
import '../core/money.dart';
import '../cubit/inventory_cubit.dart';
import '../data/inventory_item.dart';
import 'micro_animations.dart';

/// Bottom sheet used for both a fresh scan and a manual edit from the list.
/// Resolves to true when the item was saved.
Future<bool> showItemSheet(
  BuildContext context, {
  required InventoryCubit cubit,
  required String barcode,
  bool scanned = false,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ItemSheet(
      cubit: cubit,
      barcode: barcode,
      existing: cubit.find(barcode),
      scanned: scanned,
    ),
  );
  return saved ?? false;
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({
    required this.cubit,
    required this.barcode,
    required this.existing,
    required this.scanned,
  });

  final InventoryCubit cubit;
  final String barcode;
  final InventoryItem? existing;
  final bool scanned;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _price;
  final FocusNode _quantityFocus = FocusNode();

  static final DateFormat _stamp = DateFormat('MMM d, h:mm a');

  /// Duplicate scan mode: type an amount to add instead of a new total.
  bool _adding = false;

  bool get _isExisting => widget.existing != null;

  /// A scan of a barcode that is already stored.
  bool get _isDuplicateScan => widget.scanned && _isExisting;

  int? get _parsedQuantity => int.tryParse(_quantity.text);

  /// What gets stored: the typed total, or the stored count plus the typed amount.
  int get _finalQuantity => _adding
      ? widget.existing!.quantity + _parsedQuantity!
      : _parsedQuantity!;

  /// Optional: a blank or invalid price saves as zero.
  int get _parsedPrice => Money.parse(_price.text) ?? 0;

  bool get _canSave => _name.text.trim().isNotEmpty && _parsedQuantity != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _quantity = TextEditingController(text: existing?.quantity.toString() ?? '');
    _price = TextEditingController(
      text: existing != null && existing.priceCentavos > 0
          ? Money.field(existing.priceCentavos)
          : '',
    );
    if (existing != null) {
      _quantity.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _quantity.text.length,
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    _quantityFocus.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final next = ((_parsedQuantity ?? 0) + delta).clamp(0, 999999999);
    setState(() => _quantity.text = next.toString());
  }

  void _setAdding(bool adding) {
    setState(() {
      _adding = adding;
      _quantity.text = adding ? '' : widget.existing!.quantity.toString();
      _quantity.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _quantity.text.length,
      );
    });
    _quantityFocus.requestFocus();
  }

  Future<void> _save() async {
    if (!_canSave) return;
    await widget.cubit.save(
      barcode: widget.barcode,
      name: _name.text,
      quantity: _finalQuantity,
      priceCentavos: _parsedPrice,
    );
    HapticFeedback.lightImpact();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final brand = BrandScope.of(context);
    final borderColor =
        isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isDuplicateScan
                  ? 'Already in inventory'
                  : _isExisting
                      ? 'Update item'
                      : 'New item',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: isDark ? Colors.white : const Color(0xFF09090B),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.qr_code_2,
                  size: 18,
                  color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.barcode,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFA1A1AA)
                          : const Color(0xFF71717A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (_isDuplicateScan) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF4F4F5),
                  borderRadius: brand.cornerStyle.smallRadius,
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: isDark ? Colors.white : const Color(0xFF09090B),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${widget.existing!.quantity} in stock · scanned ${_stamp.format(widget.existing!.scannedAt)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF09090B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SleekSegmentedControl<bool>(
                items: const {
                  false: 'Replace count',
                  true: 'Add to count',
                },
                selected: _adding,
                onChanged: _setAdding,
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: !_isExisting,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Product name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TapScale(
                  child: IconButton.filledTonal(
                    onPressed: () => _step(-1),
                    icon: const Icon(Icons.remove),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    focusNode: _quantityFocus,
                    autofocus: _isExisting,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    decoration: InputDecoration(
                      labelText: _adding ? 'Quantity to add' : 'Stock quantity',
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 12),
                TapScale(
                  child: IconButton.filledTonal(
                    onPressed: () => _step(1),
                    icon: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}(\.\d{0,2})?$')),
              ],
              decoration: InputDecoration(
                labelText: 'Unit price (optional)',
                prefixText: '${brand.currencySymbol} ',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            TapScale(
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isDark ? Colors.white : const Color(0xFF09090B),
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  disabledBackgroundColor: isDark
                      ? const Color(0xFF27272A)
                      : const Color(0xFFE4E4E7),
                  disabledForegroundColor: isDark
                      ? const Color(0xFF71717A)
                      : const Color(0xFFA1A1AA),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: brand.cornerStyle.mediumRadius,
                  ),
                ),
                child: Text(
                  !_isExisting
                      ? 'Save Item'
                      : _adding && _parsedQuantity != null
                          ? 'Update to $_finalQuantity'
                          : 'Update Item',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
