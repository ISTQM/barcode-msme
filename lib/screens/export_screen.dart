import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../services/export_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final ExportService _service = ExportService();
  final GlobalKey _buttonKey = GlobalKey();

  bool _exporting = false;

  Rect? _buttonRect() {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _export() async {
    final items = context.read<InventoryCubit>().state.items;
    if (items.isEmpty || _exporting) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final file = await _service.createFile(items);
      await _service.share(file, origin: _buttonRect());
    } catch (_) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Export failed. Try again.')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('BIR Export')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BlocBuilder<InventoryCubit, InventoryState>(
                buildWhen: (a, b) => a.items.length != b.items.length,
                builder: (context, state) {
                  final count = state.items.length;
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          count == 0
                              ? 'No items yet'
                              : '$count ${count == 1 ? 'item' : 'items'} ready',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          count == 0
                              ? 'Scan something first, then come back to export.'
                              : 'Columns: ${ExportService.headers.join(' · ')}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Spacer(),
              BlocBuilder<InventoryCubit, InventoryState>(
                buildWhen: (a, b) => a.items.isEmpty != b.items.isEmpty,
                builder: (context, state) {
                  final enabled = state.items.isNotEmpty && !_exporting;
                  return FilledButton.icon(
                    key: _buttonKey,
                    onPressed: enabled ? _export : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(80),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: _exporting
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Icon(Icons.ios_share, size: 26),
                    label: const Text('Export BIR Inventory Excel'),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 16, color: scheme.outline),
                  const SizedBox(width: 6),
                  Text(
                    'Works offline. Share by Viber, email or any app.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
