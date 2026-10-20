import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import '../cubit/inventory_cubit.dart';
import '../data/inventory_item.dart';

/// Bottom sheet used for both a fresh scan and a manual edit from the list.
/// Resolves to true when the item was saved.
Future<bool> showItemSheet(
  BuildContext context, {
  required InventoryCubit cubit,
  required String barcode,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ItemSheet(
      cubit: cubit,
      barcode: barcode,
      existing: cubit.find(barcode),
    ),
  );
  return saved ?? false;
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({
    required this.cubit,
    required this.barcode,
    required this.existing,
  });

  final InventoryCubit cubit;
  final String barcode;
  final InventoryItem? existing;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _price;

  bool get _isExisting => widget.existing != null;

  int? get _parsedQuantity => int.tryParse(_quantity.text);

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
      // Selected so a fresh count can be typed straight over the old one.
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
    super.dispose();
  }

  void _step(int delta) {
    final next = ((_parsedQuantity ?? 0) + delta).clamp(0, 999999999);
    setState(() => _quantity.text = next.toString());
  }

  Future<void> _save() async {
    if (!_canSave) return;
    await widget.cubit.save(
      barcode: widget.barcode,
      name: _name.text,
      quantity: _parsedQuantity!,
      priceCentavos: _parsedPrice,
    );
    HapticFeedback.lightImpact();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              _isExisting ? 'Update item' : 'New item',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.qr_code_2,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.barcode,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
                IconButton.filledTonal(
                  onPressed: () => _step(-1),
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    autofocus: _isExisting,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Stock quantity',
                    ),
                    style: theme.textTheme.titleLarge,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: () => _step(1),
                  icon: const Icon(Icons.add),
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
              decoration: const InputDecoration(
                labelText: 'Unit price (optional)',
                prefixText: '₱ ',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _canSave ? _save : null,
              child: Text(_isExisting ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
