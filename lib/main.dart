import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/services/mqtt_service.dart';
import 'presentation/layout/main_layout.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fire-and-forget: MQTT auto-reconnects on failure
  MqttService.instance.connect();
  runApp(const AgriMotionApp());
}

class AgriMotionApp extends StatelessWidget {
  const AgriMotionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agri Motion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainLayout(),
    );
  }
}
