import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/providers/driver_auth_provider.dart';
import 'core/providers/driver_provider.dart';
import 'features/splash/splash_screen.dart';
import 'firebase_options.dart';
import 'services/firestore_order_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kUseFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Read the saved theme before building so the map initializes in the correct
  // mode from frame one (GoogleMap applies style/buildings only at init).
  final savedDark = await ThemeProvider.loadSaved();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(isDark: savedDark)),
        ChangeNotifierProvider(create: (_) => DriverAuthProvider()),
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
