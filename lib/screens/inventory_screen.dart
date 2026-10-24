import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/brand_config.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../data/inventory_item.dart';
import '../widgets/item_sheet.dart';
import '../widgets/item_tile.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  Future<void> _delete(BuildContext context, InventoryItem item) async {
    final cubit = context.read<InventoryCubit>();
    final messenger = ScaffoldMessenger.of(context);

    await cubit.delete(item.barcode);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted ${item.name}'),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () => cubit.restore(item),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InventoryCubit>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final brand = BrandScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<InventoryCubit, InventoryState>(
          buildWhen: (a, b) => a.items.length != b.items.length,
          builder: (context, state) => Row(
            children: [
              const Text('Inventory'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF27272A)
                      : const Color(0xFFE4E4E7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${state.items.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF09090B),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: cubit.search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search name or barcode',
                prefixIcon: Icon(Icons.search, size: 20),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: BlocBuilder<InventoryCubit, InventoryState>(
        builder: (context, state) {
          final items = state.visible;

          if (items.isEmpty) {
            return _EmptyState(searching: state.query.trim().isNotEmpty);
          }

          return ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Dismissible(
                key: ValueKey(item.barcode),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _delete(context, item),
                background: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.16),
                    borderRadius: brand.cornerStyle.mediumRadius,
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFEF4444),
                    size: 22,
                  ),
                ),
                child: ItemTile(
                  item: item,
                  onTap: () => showItemSheet(
                    context,
                    cubit: cubit,
                    barcode: item.barcode,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF18181B)
                    : const Color(0xFFF4F4F5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF27272A)
                      : const Color(0xFFE4E4E7),
                ),
              ),
              child: Icon(
                searching
                    ? Icons.search_off_rounded
                    : Icons.inventory_2_outlined,
                size: 40,
                color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              searching ? 'No matches found' : 'No items yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : const Color(0xFF09090B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              searching
                  ? 'Try checking the barcode or name spelling.'
                  : 'Scan a barcode from the Scan tab to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark
                    ? const Color(0xFFA1A1AA)
                    : const Color(0xFF71717A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
