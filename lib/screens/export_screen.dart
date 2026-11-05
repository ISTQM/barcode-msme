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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brand = BrandScope.of(context);
    final borderColor =
        isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

    return Scaffold(
      appBar: AppBar(title: const Text('BIR Export')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            Text(
              'REPORT SUMMARY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color:
                    isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
              ),
            ),
            const SizedBox(height: 8),
            BlocBuilder<InventoryCubit, InventoryState>(
              buildWhen: (a, b) => a.items.length != b.items.length,
              builder: (context, state) {
                final count = state.items.length;
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141416) : Colors.white,
                    borderRadius: brand.cornerStyle.mediumRadius,
                    border: Border.all(color: borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF27272A)
                              : const Color(0xFFF4F4F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.table_chart_outlined,
                          size: 26,
                          color:
                              isDark ? Colors.white : const Color(0xFF09090B),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              count == 0
                                  ? 'No items stored'
                                  : '$count ${count == 1 ? 'item' : 'items'} ready',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF09090B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              count == 0
                                  ? 'Scan inventory items first.'
                                  : 'Formatted per BIR specifications.',
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : const Color(0xFF09090B).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'XLSX',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color:
                                isDark ? Colors.white : const Color(0xFF09090B),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'SPECIFICATIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color:
                    isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Workbook Sheet',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFFA1A1AA)
                              : const Color(0xFF71717A),
                        ),
                      ),
                      Text(
                        ExportService.sheetName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF09090B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: borderColor, height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'Exported Columns',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF27272A)
                                : const Color(0xFFF4F4F5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            header,
                            style: TextStyle(
                              fontSize: 11.5,
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
            ),
            const SizedBox(height: 32),
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
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      disabledBackgroundColor: isDark
                          ? const Color(0xFF27272A)
                          : const Color(0xFFE4E4E7),
                      disabledForegroundColor: isDark
                          ? const Color(0xFF71717A)
                          : const Color(0xFFA1A1AA),
                      minimumSize: const Size.fromHeight(62),
                      shape: RoundedRectangleBorder(
                        borderRadius: brand.cornerStyle.mediumRadius,
                      ),
                    ),
                    icon: _exporting
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          )
                        : const Icon(Icons.ios_share, size: 20),
                    label: const Text(
                      'Export BIR Inventory Excel',
                      style: TextStyle(
                        fontSize: 15.5,
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
                  size: 14,
                  color: isDark
                      ? const Color(0xFF71717A)
                      : const Color(0xFFA1A1AA),
                ),
                const SizedBox(width: 6),
                Text(
                  'Generated locally. Share via Viber, Drive, or Email.',
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
    );
  }
}
