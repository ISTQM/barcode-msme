import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/money.dart';
import '../cubit/receipt_cubit.dart';
import '../cubit/receipt_state.dart';
import '../data/receipt.dart';
import '../services/receipt_service.dart';
import '../widgets/item_picker.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final ReceiptService _service = ReceiptService();
  final GlobalKey _buttonKey = GlobalKey();

  bool _busy = false;

  Rect? _buttonRect() {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _printAndShare() async {
    final cubit = context.read<ReceiptCubit>();
    if (cubit.state.lines.isEmpty || _busy) return;

    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await _service.printAndShare(cubit.build(), origin: _buttonRect());
    } catch (_) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Could not create the receipt. Try again.')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReceiptCubit>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          BlocBuilder<ReceiptCubit, ReceiptState>(
            buildWhen: (a, b) => a.lines.isEmpty != b.lines.isEmpty,
            builder: (context, state) => state.lines.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear receipt',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: cubit.clear,
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                const _Options(),
                BlocBuilder<ReceiptCubit, ReceiptState>(
                  buildWhen: (a, b) => a.lines.length != b.lines.length,
                  builder: (context, state) {
                    if (state.lines.isEmpty) return const _EmptyHint();
                    return Column(
                      children: [
                        for (final line in state.lines)
                          _LineCard(key: ValueKey(line.barcode), barcode: line.barcode),
                      ],
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: () => showItemPicker(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                ),
              ],
            ),
          ),
          _Footer(
            buttonKey: _buttonKey,
            busy: _busy,
            onPrintAndShare: _printAndShare,
          ),
        ],
      ),
    );
  }
}

class _Options extends StatelessWidget {
  const _Options();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReceiptCubit>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: BlocBuilder<ReceiptCubit, ReceiptState>(
        buildWhen: (a, b) => a.type != b.type || a.paper != b.paper,
        builder: (context, state) {
          return Column(
            children: [
              SegmentedButton<ReceiptType>(
                showSelectedIcon: false,
                segments: [
                  for (final type in ReceiptType.values)
                    ButtonSegment(value: type, label: Text(type.label)),
                ],
                selected: {state.type},
                onSelectionChanged: (s) => cubit.setType(s.first),
              ),
              const SizedBox(height: 8),
              SegmentedButton<PaperWidth>(
                showSelectedIcon: false,
                segments: [
                  for (final paper in PaperWidth.values)
                    ButtonSegment(
                      value: paper,
                      label: Text(paper.label),
                      icon: const Icon(Icons.receipt_long_outlined),
                    ),
                ],
                selected: {state.paper},
                onSelectionChanged: (s) => cubit.setPaper(s.first),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('No items yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Add items to build a receipt.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One receipt line. Reads its own line from the cubit so only this card
/// rebuilds when its quantity or price changes.
class _LineCard extends StatefulWidget {
  const _LineCard({super.key, required this.barcode});

  final String barcode;

  @override
  State<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends State<_LineCard> {
  late final TextEditingController _quantity;
  late final TextEditingController _price;
  final FocusNode _quantityFocus = FocusNode();

  ReceiptLine _line(ReceiptState state) =>
      state.lines.firstWhere((l) => l.barcode == widget.barcode);

  @override
  void initState() {
    super.initState();
    final line = _line(context.read<ReceiptCubit>().state);
    _quantity = TextEditingController(text: '${line.quantity}');
    _price = TextEditingController(
      text: line.unitPriceCentavos > 0 ? Money.field(line.unitPriceCentavos) : '',
    );
    // An empty or zero quantity snaps back to the real one when you leave.
    _quantityFocus.addListener(() {
      if (!_quantityFocus.hasFocus) _syncQuantity();
    });
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _quantityFocus.dispose();
    super.dispose();
  }

  void _syncQuantity() {
    final quantity = _line(context.read<ReceiptCubit>().state).quantity;
    if (_quantity.text != '$quantity') _quantity.text = '$quantity';
  }

  void _step(int delta) {
    final cubit = context.read<ReceiptCubit>();
    cubit.setQuantity(widget.barcode, _line(cubit.state).quantity + delta);
    _syncQuantity();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.read<ReceiptCubit>();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 12),
        child: BlocBuilder<ReceiptCubit, ReceiptState>(
          buildWhen: (a, b) =>
              !b.lines.any((l) => l.barcode == widget.barcode) ||
              _line(a) != _line(b),
          builder: (context, state) {
            if (!state.lines.any((l) => l.barcode == widget.barcode)) {
              return const SizedBox.shrink();
            }
            final line = _line(state);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close),
                      onPressed: () => cubit.remove(widget.barcode),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _step(-1),
                        icon: const Icon(Icons.remove),
                      ),
                      SizedBox(
                        width: 56,
                        child: TextField(
                          controller: _quantity,
                          focusNode: _quantityFocus,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (text) {
                            final value = int.tryParse(text);
                            if (value != null && value >= 1) {
                              cubit.setQuantity(widget.barcode, value);
                            }
                          },
                        ),
                      ),
                      IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _step(1),
                        icon: const Icon(Icons.add),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d{0,7}(\.\d{0,2})?$'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Unit price',
                            prefixText: '₱ ',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (text) => cubit.setUnitPrice(
                            widget.barcode,
                            Money.parse(text) ?? 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    'Amount  ${Money.peso(line.amountCentavos)}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.buttonKey,
    required this.busy,
    required this.onPrintAndShare,
  });

  final GlobalKey buttonKey;
  final bool busy;
  final VoidCallback onPrintAndShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: BlocBuilder<ReceiptCubit, ReceiptState>(
            buildWhen: (a, b) => a.totalCentavos != b.totalCentavos ||
                a.lines.isEmpty != b.lines.isEmpty,
            builder: (context, state) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: theme.textTheme.titleMedium),
                      Text(
                        Money.peso(state.totalCentavos),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: buttonKey,
                    onPressed: state.lines.isEmpty || busy ? null : onPrintAndShare,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                    ),
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Icon(Icons.print_outlined),
                    label: const Text('Print / Share'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
