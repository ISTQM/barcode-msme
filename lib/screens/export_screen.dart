import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/brand_config.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../services/export_service.dart';
import '../widgets/micro_animations.dart';

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
        ..showSnackBar(
          const SnackBar(content: Text('Export failed. Try again.')),
        );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final brand = BrandScope.of(context);
    final borderColor =
        isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

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
                      color: isDark ? const Color(0xFF141416) : Colors.white,
                      borderRadius: brand.cornerStyle.largeRadius,
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.3 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF27272A)
                                    : const Color(0xFFF4F4F5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.table_chart_outlined,
                                size: 24,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF09090B),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    count == 0
                                        ? 'Inventory is empty'
                                        : '$count ${count == 1 ? 'item' : 'items'} ready',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF09090B),
                                    ),
                                  ),
                                  Text(
                                    'Excel (.xlsx) spreadsheet format',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark
                                          ? const Color(0xFFA1A1AA)
                                          : const Color(0xFF71717A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Divider(color: borderColor, height: 1),
                        const SizedBox(height: 14),
                        Text(
                          'Included Columns',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isDark
                                ? const Color(0xFFA1A1AA)
                                : const Color(0xFF71717A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final header in ExportService.headers)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF27272A)
                                      : const Color(0xFFF4F4F5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Text(
                                  header,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF09090B),
                                  ),
                                ),
                              ),
                          ],
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
                  return TapScale(
                    child: FilledButton.icon(
                      key: _buttonKey,
                      onPressed: enabled ? _export : null,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            isDark ? Colors.white : const Color(0xFF09090B),
                        foregroundColor:
                            isDark ? Colors.black : Colors.white,
                        disabledBackgroundColor: isDark
                            ? const Color(0xFF27272A)
                            : const Color(0xFFE4E4E7),
                        disabledForegroundColor: isDark
                            ? const Color(0xFF71717A)
                            : const Color(0xFFA1A1AA),
                        minimumSize: const Size.fromHeight(68),
                        shape: RoundedRectangleBorder(
                          borderRadius: brand.cornerStyle.mediumRadius,
                        ),
                      ),
                      icon: _exporting
                          ? SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            )
                          : const Icon(Icons.ios_share, size: 22),
                      label: const Text(
                        'Export BIR Inventory Excel',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off,
                    size: 15,
                    color: isDark
                        ? const Color(0xFF71717A)
                        : const Color(0xFFA1A1AA),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Built on device. Share via Viber, Drive, email or printer.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF71717A)
                          : const Color(0xFFA1A1AA),
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
