import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../widgets/item_sheet.dart';
import '../widgets/item_tile.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InventoryCubit>();

    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<InventoryCubit, InventoryState>(
          buildWhen: (a, b) => a.items.length != b.items.length,
          builder: (context, state) => Text('Inventory (${state.items.length})'),
        ),
      ),
      body: BlocBuilder<InventoryCubit, InventoryState>(
        builder: (context, state) {
          final items = state.visible;

          if (items.isEmpty) {
            return const _EmptyState();
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ItemTile(
                key: ValueKey(item.barcode),
                item: item,
                onTap: () => showItemSheet(
                  context,
                  cubit: cubit,
                  barcode: item.barcode,
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('Nothing here yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Scanned items show up here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
