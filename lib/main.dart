import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dokkan/core/constants/app_strings.dart';
import 'package:dokkan/core/theme/app_theme.dart';
import 'package:dokkan/providers/exchange_rate_provider.dart';
import 'package:dokkan/providers/inventory_provider.dart';
import 'package:dokkan/providers/sales_provider.dart';
import 'package:dokkan/presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExchangeRateProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
      ],
      child: const DokkanApp(),
    ),
  );
}

class DokkanApp extends StatelessWidget {
  const DokkanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const HomeScreen(),
    );
  }
}
