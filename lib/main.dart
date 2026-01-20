import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'theme.dart';
import 'theme/theme_controller.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/resident_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔹 Load saved theme
  final themeController = ThemeController();
  await themeController.loadTheme();

  runApp(SmartStayApp(themeController: themeController));
}

class SmartStayApp extends StatelessWidget {
  final ThemeController themeController;

  const SmartStayApp({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (_, __) {
        return MaterialApp(
          title: 'SmartStay',
          debugShowCheckedModeBanner: false,

          // 🌞 Light Theme
          theme: AppTheme.lightTheme.copyWith(
            textTheme: AppTheme.lightTheme.textTheme.apply(fontFamily: 'Inter'),
          ),

          // 🌙 Dark Theme
          darkTheme: AppTheme.darkTheme.copyWith(
            textTheme: AppTheme.darkTheme.textTheme.apply(fontFamily: 'Inter'),
          ),

          // 🔁 Controlled by ThemeController
          themeMode: themeController.themeMode,

          home: const LoginScreen(),

          routes: {
            '/login': (_) => const LoginScreen(),
            '/admin': (_) => const AdminDashboard(),
            '/resident': (_) => const ResidentDashboard(),
          },
        );
      },
    );
  }
}
