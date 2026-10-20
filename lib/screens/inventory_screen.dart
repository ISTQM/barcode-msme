import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
            onPressed: () => cubit.restore(item),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InventoryCubit>();

    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<InventoryCubit, InventoryState>(
          buildWhen: (a, b) => a.items.length != b.items.length,
          builder: (context, state) => Text('Inventory (${state.items.length})'),
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
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
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
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Dismissible(
                key: ValueKey(item.barcode),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _delete(context, item),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off : Icons.inventory_2_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              searching ? 'No matches' : 'Nothing here yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              searching
                  ? 'Try another name or barcode.'
                  : 'Scanned items show up here.',
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
