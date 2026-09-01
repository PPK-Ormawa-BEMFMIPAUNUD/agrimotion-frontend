import 'package:flutter/material.dart';
import 'package:agrimotion/core/theme/app_theme.dart';
import 'package:agrimotion/core/services/mqtt_service.dart';
import 'package:agrimotion/mobile/presentation/layout/mobile_main_layout.dart';

void main() {
  runMobileApp();
}

void runMobileApp() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fire-and-forget: MQTT auto-reconnects on failure for mobile app
  MqttService.instance.connect();
  runApp(const AgriMotionMobileApp());
}

class AgriMotionMobileApp extends StatelessWidget {
  const AgriMotionMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriMotion Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MobileMainLayout(),
    );
  }
}
