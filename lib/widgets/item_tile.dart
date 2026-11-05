import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/brand_config.dart';
import '../core/money.dart';
import '../data/inventory_item.dart';
import 'micro_animations.dart';

class ItemTile extends StatelessWidget {
  const ItemTile({super.key, required this.item, required this.onTap});

  final InventoryItem item;
  final VoidCallback onTap;

  static final DateFormat _stamp = DateFormat('MMM d · h:mm a');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final brand = BrandScope.of(context);
    final borderColor =
        isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

    return TapScale(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141416) : Colors.white,
          borderRadius: brand.cornerStyle.mediumRadius,
          border: Border.all(color: borderColor, width: 1),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : const Color(0xFF09090B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF27272A)
                              : const Color(0xFFF4F4F5),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          item.barcode,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFFA1A1AA)
                                : const Color(0xFF71717A),
                          ),
                        ),
                      ),
                      if (item.priceCentavos > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          Money.peso(item.priceCentavos),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF09090B),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _stamp.format(item.scannedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF71717A)
                          : const Color(0xFFA1A1AA),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            PopBadge(
              valueKey: item.quantity,
              child: Container(
                constraints: const BoxConstraints(minWidth: 46),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                  borderRadius: brand.cornerStyle.smallRadius,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF3F3F46)
                        : const Color(0xFFE4E4E7),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${item.quantity}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF09090B),
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
