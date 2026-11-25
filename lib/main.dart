import 'package:flutter/material.dart';

import 'app/app_controller.dart';
import 'app/app_theme.dart';
import 'app/app_ui.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TetesApp());
}

class TetesApp extends StatefulWidget {
  const TetesApp({super.key});

  @override
  State<TetesApp> createState() => _TetesAppState();
}

class _TetesAppState extends State<TetesApp> {
  final controller = AppController();

  @override
  void initState() {
    super.initState();
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Tetes Praktikum',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (controller.error != null) {
          return Scaffold(
            body: AppStateView(
              icon: Icons.cloud_off_rounded,
              message: controller.error!,
            ),
          );
        }
        return controller.userId == null
            ? AuthScreen(controller: controller)
            : HomeScreen(controller: controller);
      },
    ),
  );
}
