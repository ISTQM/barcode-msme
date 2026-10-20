import 'package:flutter/material.dart';

import 'core/app_theme.dart';

void main() {
  runApp(const StockScanApp());
}

class StockScanApp extends StatelessWidget {
  const StockScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Scan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const Scaffold(body: Center(child: Text('Stock Scan'))),
    );
  }
}
