import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/app_theme.dart';
import 'cubit/inventory_cubit.dart';
import 'cubit/receipt_cubit.dart';
import 'data/inventory_repository.dart';
import 'screens/home_shell.dart';

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
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => InventoryCubit(repository)),
        BlocProvider(create: (_) => ReceiptCubit()),
      ],
      child: MaterialApp(
        title: 'Stock Scan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const HomeShell(),
      ),
    );
  }
}
