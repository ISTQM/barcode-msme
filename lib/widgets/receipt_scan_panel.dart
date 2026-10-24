import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/brand_config.dart';
import '../core/money.dart';
import '../cubit/receipt_cubit.dart';
import '../cubit/receipt_state.dart';
import '../data/receipt.dart';
import 'micro_animations.dart';

/// What the most recent counter scan did.
class ReceiptScanResult {
  const ReceiptScanResult.added(this.barcode) : unknown = false;
  const ReceiptScanResult.unknown(this.barcode) : unknown = true;

  final String barcode;

  /// True when the barcode is not in inventory, so nothing was added.
  final bool unknown;
}

/// Sits at the bottom of the Counter scanner. Shows the last scanned item,
/// running total, quantity controls, and the CTA to review the customer receipt.
class ReceiptScanPanel extends StatelessWidget {
  const ReceiptScanPanel({
    super.key,
    required this.last,
    required this.onAddUnknown,
    required this.onReview,
  });

  final ReceiptScanResult? last;
  final ValueChanged<String> onAddUnknown;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final brand = BrandScope.of(context);
    final borderColor =
        isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121214) : Colors.white,
        borderRadius: brand.cornerStyle.sheetRadius,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
          left: BorderSide(color: borderColor, width: 1),
          right: BorderSide(color: borderColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: BlocBuilder<ReceiptCubit, ReceiptState>(
            builder: (context, state) {
              final lines = state.lines;
              final units = lines.fold<int>(0, (sum, l) => sum + l.quantity);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _lastRow(context, state),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: lines.isEmpty
                            ? Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E1E22)
                                          : const Color(0xFFF4F4F5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.point_of_sale_outlined,
                                      size: 20,
                                      color: isDark
                                          ? const Color(0xFFA1A1AA)
                                          : const Color(0xFF71717A),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Customer Counter',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF09090B),
                                          ),
                                        ),
                                        Text(
                                          'Scan customer items one by one',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? const Color(0xFFA1A1AA)
                                                : const Color(0xFF71717A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${lines.length} ${lines.length == 1 ? 'item' : 'items'}'
                                    ' · $units pcs',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFFA1A1AA)
                                          : const Color(0xFF71717A),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    Money.peso(state.totalCentavos),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF09090B),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      if (lines.isNotEmpty)
                        TapScale(
                          child: FilledButton.icon(
                            onPressed: onReview,
                            style: FilledButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.white
                                  : const Color(0xFF09090B),
                              foregroundColor: isDark
                                  ? Colors.black
                                  : Colors.white,
                              minimumSize: const Size(140, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: brand.cornerStyle.smallRadius,
                              ),
                            ),
                            icon: const Icon(Icons.receipt_long, size: 18),
                            label: const Text(
                              'Review Receipt',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _lastRow(BuildContext context, ReceiptState state) {
    final result = last;
    if (result == null) return const SizedBox(width: double.infinity);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brand = BrandScope.of(context);

    if (result.unknown) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
          borderRadius: brand.cornerStyle.smallRadius,
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFEF4444),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Not in inventory',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  Text(
                    result.barcode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      color: isDark
                          ? const Color(0xFFA1A1AA)
                          : const Color(0xFF71717A),
                    ),
                  ),
                ],
              ),
            ),
            TapScale(
              child: TextButton(
                onPressed: () => onAddUnknown(result.barcode),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor:
                      isDark ? Colors.white : const Color(0xFF09090B),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                child: const Text('Add item'),
              ),
            ),
          ],
        ),
      );
    }

    ReceiptLine? line;
    for (final candidate in state.lines) {
      if (candidate.barcode == result.barcode) line = candidate;
    }
    if (line == null) return const SizedBox(width: double.infinity);

    return Container(
      key: ValueKey('${line.barcode}-${line.quantity}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF4F4F5),
        borderRadius: brand.cornerStyle.smallRadius,
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          PopBadge(
            valueKey: line.quantity,
            child: Container(
              constraints: const BoxConstraints(minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : const Color(0xFF09090B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '×${line.quantity}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : const Color(0xFF09090B),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  line.unitPriceCentavos > 0
                      ? '${Money.peso(line.unitPriceCentavos)} each · '
                          '${Money.peso(line.amountCentavos)}'
                      : 'No price set',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFFA1A1AA)
                        : const Color(0xFF71717A),
                  ),
                ),
              ],
            ),
          ),
          TapScale(
            child: IconButton(
              tooltip: 'Remove one',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.remove_circle_outline,
                size: 20,
                color: isDark
                    ? const Color(0xFFA1A1AA)
                    : const Color(0xFF71717A),
              ),
              onPressed: () =>
                  context.read<ReceiptCubit>().decrement(line!.barcode),
            ),
          ),
        ],
      ),
    );
  }
}
