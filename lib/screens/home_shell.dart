import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'counter_screen.dart';
import 'export_screen.dart';
import 'inventory_screen.dart';

/// Main navigation shell.
/// 3 core retail tabs: Counter (cashier session), Inventory (products & stock intake), Export (reports).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int index) {
    if (_index == index) return;
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          CounterScreen(active: _index == 0),
          const InventoryScreen(),
          const ExportScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: borderColor, width: 0.8),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: isDark
                ? const Color(0xFF27272A)
                : const Color(0xFFE4E4E7),
            destinations: [
              _buildDestination(
                icon: Icons.point_of_sale_outlined,
                selectedIcon: Icons.point_of_sale,
                label: 'Counter',
                isSelected: _index == 0,
              ),
              _buildDestination(
                icon: Icons.inventory_2_outlined,
                selectedIcon: Icons.inventory_2,
                label: 'Inventory',
                isSelected: _index == 1,
              ),
              _buildDestination(
                icon: Icons.ios_share_outlined,
                selectedIcon: Icons.ios_share,
                label: 'Export',
                isSelected: _index == 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  NavigationDestination _buildDestination({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
  }) {
    return NavigationDestination(
      icon: AnimatedScale(
        scale: isSelected ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Icon(icon, size: 22),
      ),
      selectedIcon: AnimatedScale(
        scale: 1.1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Icon(selectedIcon, size: 22),
      ),
      label: label,
    );
  }
}
