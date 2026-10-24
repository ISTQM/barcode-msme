import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/money.dart';
import '../cubit/receipt_cubit.dart';
import '../cubit/receipt_state.dart';
import '../data/receipt.dart';

/// What the most recent receipt-mode scan did.
class ReceiptScanResult {
  const ReceiptScanResult.added(this.barcode) : unknown = false;
  const ReceiptScanResult.unknown(this.barcode) : unknown = true;

  final String barcode;

  /// True when the barcode is not in inventory, so nothing was added.
  final bool unknown;
}

/// Sits over the camera in receipt mode. Shows the last scan, with its running
/// quantity so repeated scans of one product are easy to follow, and the
/// receipt total.
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
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: BlocBuilder<ReceiptCubit, ReceiptState>(
          builder: (context, state) {
            final lines = state.lines;
            final units = lines.fold<int>(0, (sum, l) => sum + l.quantity);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.topCenter,
                  child: _lastRow(context, state),
                ),
                Row(
                  children: [
                    Expanded(
                      child: lines.isEmpty
                          ? Text(
                              'Scan items to build a receipt',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${lines.length} ${lines.length == 1 ? 'item' : 'items'}'
                                  ' · $units pcs',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  Money.peso(state.totalCentavos),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (lines.isNotEmpty)
                      FilledButton.icon(
                        onPressed: onReview,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Review'),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _lastRow(BuildContext context, ReceiptState state) {
    final result = last;
    if (result == null) return const SizedBox(width: double.infinity);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (result.unknown) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: scheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Not in inventory', style: theme.textTheme.titleSmall),
                  Text(
                    result.barcode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => onAddUnknown(result.barcode),
              child: const Text('Add item'),
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

    return Padding(
      key: ValueKey('${line.barcode}-${line.quantity}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '×${line.quantity}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
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
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  line.unitPriceCentavos > 0
                      ? '${Money.peso(line.unitPriceCentavos)} each · '
                          '${Money.peso(line.amountCentavos)}'
                      : 'No price set',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove one',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () =>
                context.read<ReceiptCubit>().decrement(line!.barcode),
          ),
        ],
      ),
    );
  }
}
