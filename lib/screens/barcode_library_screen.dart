import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/brand_config.dart';
import '../cubit/barcode_cubit.dart';
import '../cubit/barcode_state.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../data/product_barcode.dart';
import '../widgets/barcode_tile.dart';
import '../widgets/micro_animations.dart';
import 'barcode_create_screen.dart';
import 'label_export_screen.dart';

/// The shop's own barcodes: make a new one, reprint an old one.
class BarcodeLibraryScreen extends StatelessWidget {
  const BarcodeLibraryScreen({super.key});

  void _create(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BarcodeCreateScreen()),
    );
  }

  void _print(BuildContext context, ProductBarcode product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LabelExportScreen(barcode: product.barcode),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ProductBarcode product,
  ) async {
    final cubit = context.read<BarcodeCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${product.name}?'),
        content: const Text(
          'This removes the barcode record and its photo. '
          'The inventory item, if there is one, is not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.delete(product.barcode);
  }

  Future<void> _addToInventory(
    BuildContext context,
    ProductBarcode product,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await context.read<InventoryCubit>().save(
          barcode: product.barcode,
          name: product.name,
          quantity: 0,
          priceCentavos: product.priceCentavos,
        );
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('${product.name} added to inventory')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brand = BrandScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<BarcodeCubit, BarcodeState>(
          buildWhen: (a, b) => a.items.length != b.items.length,
          builder: (context, state) => Row(
            children: [
              const Text('Barcodes'),
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
      ),
      floatingActionButton: TapScale(
        child: FloatingActionButton.extended(
          heroTag: 'new_barcode_fab',
          onPressed: () => _create(context),
          backgroundColor: isDark ? Colors.white : const Color(0xFF09090B),
          foregroundColor: isDark ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: brand.cornerStyle.mediumRadius,
          ),
          icon: const Icon(Icons.add, size: 20),
          label: const Text(
            'New Barcode',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      body: BlocBuilder<BarcodeCubit, BarcodeState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return _EmptyState(onCreate: () => _create(context));
          }

          return BlocBuilder<InventoryCubit, InventoryState>(
            buildWhen: (a, b) => a.items != b.items,
            builder: (context, inventory) {
              final known = {for (final item in inventory.items) item.barcode};
              final cubit = context.read<BarcodeCubit>();
              return ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 88),
                itemCount: state.items.length,
                itemBuilder: (context, index) {
                  final product = state.items[index];
                  return BarcodeTile(
                    key: ValueKey(product.barcode),
                    product: product,
                    photo: cubit.photoOf(product),
                    inInventory: known.contains(product.barcode),
                    onTap: () => _print(context, product),
                    onAction: (action) => switch (action) {
                      BarcodeTileAction.print => _print(context, product),
                      BarcodeTileAction.addToInventory =>
                        _addToInventory(context, product),
                      BarcodeTileAction.delete =>
                        _confirmDelete(context, product),
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brand = BrandScope.of(context);
    final muted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF27272A)
                      : const Color(0xFFE4E4E7),
                ),
              ),
              child: Icon(Icons.qr_code_2, size: 40, color: muted),
            ),
            const SizedBox(height: 18),
            Text(
              'No barcodes yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : const Color(0xFF09090B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Make a barcode for a product that has none, then print the '
              'labels and stick them on.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: muted),
            ),
            const SizedBox(height: 20),
            TapScale(
              child: FilledButton.icon(
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isDark ? Colors.white : const Color(0xFF09090B),
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  minimumSize: const Size(160, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: brand.cornerStyle.mediumRadius,
                  ),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text(
                  'New Barcode',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
