import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/money.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../cubit/receipt_cubit.dart';
import '../cubit/receipt_state.dart';

/// Pick inventory items for the receipt. Stays open so several items can be
/// added in a row; each tap adds one unit.
Future<void> showItemPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ItemPicker(),
  );
}

class _ItemPicker extends StatefulWidget {
  const _ItemPicker();

  @override
  State<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends State<_ItemPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final receipt = context.read<ReceiptCubit>();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add items', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search name or barcode',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<InventoryCubit, InventoryState>(
                builder: (context, state) {
                  final q = _query.trim().toLowerCase();
                  final items = q.isEmpty
                      ? state.items
                      : state.items
                          .where(
                            (i) =>
                                i.name.toLowerCase().contains(q) ||
                                i.barcode.toLowerCase().contains(q),
                          )
                          .toList();

                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        state.items.isEmpty
                            ? 'Scan items first, then add them here.'
                            : 'No matches.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        title: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item.priceCentavos > 0
                              ? '${item.barcode} · ${Money.peso(item.priceCentavos)}'
                              : item.barcode,
                        ),
                        trailing: BlocBuilder<ReceiptCubit, ReceiptState>(
                          buildWhen: (a, b) =>
                              _qty(a, item.barcode) != _qty(b, item.barcode),
                          builder: (context, state) {
                            final qty = _qty(state, item.barcode);
                            return qty == 0
                                ? const Icon(Icons.add_circle_outline)
                                : Chip(label: Text('× $qty'));
                          },
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          receipt.addItem(item);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _qty(ReceiptState state, String barcode) {
    for (final line in state.lines) {
      if (line.barcode == barcode) return line.quantity;
    }
    return 0;
  }
}
