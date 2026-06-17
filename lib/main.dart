import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/providers/driver_provider.dart';
import 'features/splash/splash_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DriverProvider()),
      ],
      child: const UniEatsDriverApp(),
    ),
  );
}

class UniEatsDriverApp extends StatelessWidget {
  const UniEatsDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeP = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'Uni Eats Driver',
      debugShowCheckedModeBanner: false,
      themeMode: themeP.themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}
