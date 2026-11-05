import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/app_theme.dart';
import 'core/brand_config.dart';
import 'cubit/inventory_cubit.dart';
import 'cubit/receipt_cubit.dart';
import 'data/inventory_repository.dart';
import 'screens/splash_screen.dart';
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
    this.brandConfig = BrandConfig.mobbinMonochrome,
  });

  final InventoryRepository repository;
  final ScanFeedback feedback;
  final BrandConfig brandConfig;

  @override
  Widget build(BuildContext context) {
    return BrandScope(
      config: brandConfig,
      child: RepositoryProvider.value(
        value: feedback,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => InventoryCubit(repository)),
            BlocProvider(create: (_) => ReceiptCubit()),
          ],
          child: MaterialApp(
            title: brandConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(brandConfig),
            darkTheme: AppTheme.dark(brandConfig),
            home: const SplashScreen(),
          ),
        ),
      ),
    );
  }
}
