import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/app_theme.dart';
import 'cubit/inventory_cubit.dart';
import 'data/inventory_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await InventoryRepository.open();
  runApp(StockScanApp(repository: repository));
}

class StockScanApp extends StatelessWidget {
  const StockScanApp({super.key, required this.repository});

  final InventoryRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InventoryCubit(repository),
      child: MaterialApp(
        title: 'Stock Scan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const Scaffold(body: Center(child: Text('Stock Scan'))),
      ),
    );
  }
}
