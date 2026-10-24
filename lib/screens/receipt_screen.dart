import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/brand_config.dart';
import '../core/money.dart';
import '../cubit/receipt_cubit.dart';
import '../cubit/receipt_state.dart';
import '../data/receipt.dart';
import '../services/receipt_service.dart';
import '../widgets/item_picker.dart';
import '../widgets/micro_animations.dart';

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
          const SnackBar(
            content: Text('Could not create the receipt. Try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReceiptCubit>();
    final brand = BrandScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          BlocBuilder<ReceiptCubit, ReceiptState>(
            buildWhen: (a, b) => a.lines.isEmpty != b.lines.isEmpty,
            builder: (context, state) => state.lines.isEmpty
                ? const SizedBox.shrink()
                : TapScale(
                    child: IconButton(
                      tooltip: 'Clear receipt',
                      icon: const Icon(Icons.delete_sweep_outlined),
                      onPressed: cubit.clear,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const _Options(),
                BlocBuilder<ReceiptCubit, ReceiptState>(
                  buildWhen: (a, b) => a.lines.length != b.lines.length,
                  builder: (context, state) {
                    if (state.lines.isEmpty) return const _EmptyHint();
                    return Column(
                      children: [
                        for (final line in state.lines)
                          _LineCard(
                            key: ValueKey(line.barcode),
                            barcode: line.barcode,
                          ),
                      ],
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: TapScale(
                    child: OutlinedButton.icon(
                      onPressed: () => showItemPicker(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: brand.cornerStyle.mediumRadius,
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text(
                        'Add item',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
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
              SleekSegmentedControl<ReceiptType>(
                items: {
                  for (final type in ReceiptType.values) type: type.label,
                },
                selected: state.type,
                onChanged: cubit.setType,
              ),
              const SizedBox(height: 8),
              SleekSegmentedControl<PaperWidth>(
                items: {
                  for (final paper in PaperWidth.values) paper: paper.label,
                },
                selected: state.paper,
                onChanged: cubit.setPaper,
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
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
              ),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 38,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No items on receipt',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : const Color(0xFF09090B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add items from inventory or scan in Receipt mode.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
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
      text: line.unitPriceCentavos > 0
          ? Money.field(line.unitPriceCentavos)
          : '',
    );
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
    final isDark = theme.brightness == Brightness.dark;
    final brand = BrandScope.of(context);
    final borderColor =
        isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
    final cubit = context.read<ReceiptCubit>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF09090B),
                      ),
                    ),
                  ),
                  TapScale(
                    child: IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: isDark
                            ? const Color(0xFFA1A1AA)
                            : const Color(0xFF71717A),
                      ),
                      onPressed: () => cubit.remove(widget.barcode),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  children: [
                    TapScale(
                      child: IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _step(-1),
                        icon: const Icon(Icons.remove, size: 16),
                      ),
                    ),
                    SizedBox(
                      width: 54,
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
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (text) {
                          final value = int.tryParse(text);
                          if (value != null && value >= 1) {
                            cubit.setQuantity(widget.barcode, value);
                          }
                        },
                      ),
                    ),
                    TapScale(
                      child: IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _step(1),
                        icon: const Icon(Icons.add, size: 16),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Unit price',
                          prefixText: '${brand.currencySymbol} ',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
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
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  'Amount  ${Money.peso(line.amountCentavos)}',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF09090B),
                  ),
                ),
              ),
            ],
          );
        },
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
    final isDark = theme.brightness == Brightness.dark;
    final brand = BrandScope.of(context);
    final borderColor =
        isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D0E) : Colors.white,
        border: Border(top: BorderSide(color: borderColor, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: BlocBuilder<ReceiptCubit, ReceiptState>(
            buildWhen: (a, b) =>
                a.totalCentavos != b.totalCentavos ||
                a.lines.isEmpty != b.lines.isEmpty,
            builder: (context, state) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFA1A1AA)
                              : const Color(0xFF71717A),
                        ),
                      ),
                      Text(
                        Money.peso(state.totalCentavos),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF09090B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TapScale(
                    child: FilledButton.icon(
                      key: buttonKey,
                      onPressed:
                          state.lines.isEmpty || busy ? null : onPrintAndShare,
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white
                            : const Color(0xFF09090B),
                        foregroundColor: isDark
                            ? Colors.black
                            : Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: brand.cornerStyle.mediumRadius,
                        ),
                      ),
                      icon: busy
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            )
                          : const Icon(Icons.print_outlined, size: 20),
                      label: const Text(
                        'Print / Share',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
