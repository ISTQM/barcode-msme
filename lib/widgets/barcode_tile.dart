import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/brand_config.dart';
import '../core/money.dart';
import '../data/product_barcode.dart';
import 'micro_animations.dart';

/// Square product photo, or a quiet placeholder when there is none.
class ProductThumb extends StatelessWidget {
  const ProductThumb({super.key, required this.file, this.size = 56});

  final File? file;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brand = BrandScope.of(context);

    final placeholder = Icon(
      Icons.image_outlined,
      size: size * 0.42,
      color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
        borderRadius: brand.cornerStyle.smallRadius,
      ),
      child: file == null
          ? placeholder
          : Image.file(
              file!,
              fit: BoxFit.cover,
              // Decode at thumbnail size, not full photo size.
              cacheWidth: (size * 3).round(),
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

enum BarcodeTileAction { print, addToInventory, delete }

/// One row of the Barcodes list.
class BarcodeTile extends StatelessWidget {
  const BarcodeTile({
    super.key,
    required this.product,
    required this.photo,
    required this.inInventory,
    required this.onTap,
    required this.onAction,
  });

  final ProductBarcode product;
  final File? photo;
  final bool inInventory;
  final VoidCallback onTap;
  final ValueChanged<BarcodeTileAction> onAction;

  static final DateFormat _stamp = DateFormat('MMM d · h:mm a');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brand = BrandScope.of(context);
    final ink = isDark ? Colors.white : const Color(0xFF09090B);
    final muted = isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA);

    return TapScale(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141416) : Colors.white,
          borderRadius: brand.cornerStyle.mediumRadius,
          border: Border.all(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ProductThumb(file: photo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Chip(
                        text: product.barcode,
                        mono: true,
                      ),
                      _Chip(text: product.symbology.label),
                      if (product.priceCentavos > 0)
                        Text(
                          Money.peso(product.priceCentavos),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        inInventory
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                        size: 13,
                        color: inInventory ? const Color(0xFF22C55E) : muted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          inInventory
                              ? 'In inventory'
                              : 'Not in inventory · ${_stamp.format(product.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<BarcodeTileAction>(
              tooltip: 'More',
              icon: Icon(Icons.more_vert, size: 20, color: muted),
              onSelected: onAction,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: BarcodeTileAction.print,
                  child: Text('Print or export'),
                ),
                if (!inInventory)
                  const PopupMenuItem(
                    value: BarcodeTileAction.addToInventory,
                    child: Text('Add to inventory'),
                  ),
                const PopupMenuItem(
                  value: BarcodeTileAction.delete,
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.mono = false});

  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: mono ? 'monospace' : null,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
        ),
      ),
    );
  }
}
