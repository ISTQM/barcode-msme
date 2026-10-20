import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/app_theme.dart';
import 'cubit/inventory_cubit.dart';
import 'cubit/receipt_cubit.dart';
import 'data/inventory_repository.dart';
import 'screens/home_shell.dart';
import 'services/scan_feedback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await InventoryRepository.open();
  final feedback = await ScanFeedback.load();
  runApp(StockScanApp(repository: repository, feedback: feedback));
}

class StockScanApp extends StatelessWidget {
  const StockScanApp({
    super.key,
    required this.repository,
    required this.feedback,
  });

  final InventoryRepository repository;
  final ScanFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: feedback,
      child: MultiBlocProvider(
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
      ),
    );
  }
}
