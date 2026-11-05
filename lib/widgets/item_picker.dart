import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/brand_config.dart';
import '../core/money.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../cubit/receipt_cubit.dart';
import '../cubit/receipt_state.dart';
import 'micro_animations.dart';

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
    final isDark = theme.brightness == Brightness.dark;
    final brand = BrandScope.of(context);
    final receipt = context.read<ReceiptCubit>();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Items to Receipt',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: isDark ? Colors.white : const Color(0xFF09090B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search name or barcode',
                      prefixIcon: Icon(Icons.search, size: 20),
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
                            : 'No matches found.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? const Color(0xFFA1A1AA)
                              : const Color(0xFF71717A),
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
                      return TapScale(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          receipt.addItem(item);
                        },
                        scale: 0.98,
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF09090B),
                            ),
                          ),
                          subtitle: Text(
                            item.priceCentavos > 0
                                ? '${item.barcode} · ${Money.peso(item.priceCentavos)}'
                                : item.barcode,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? const Color(0xFFA1A1AA)
                                  : const Color(0xFF71717A),
                            ),
                          ),
                          trailing: BlocBuilder<ReceiptCubit, ReceiptState>(
                            buildWhen: (a, b) =>
                                _qty(a, item.barcode) != _qty(b, item.barcode),
                            builder: (context, state) {
                              final qty = _qty(state, item.barcode);
                              return qty == 0
                                  ? Icon(
                                      Icons.add_circle_outline,
                                      color: isDark
                                          ? const Color(0xFFA1A1AA)
                                          : const Color(0xFF71717A),
                                    )
                                  : PopBadge(
                                      valueKey: qty,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF09090B),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '× $qty',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: TapScale(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isDark ? Colors.white : const Color(0xFF09090B),
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: brand.cornerStyle.mediumRadius,
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
