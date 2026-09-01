import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:agrimotion/core/router/app_router.dart';
import 'package:agrimotion/core/theme/app_theme.dart';
import 'package:agrimotion/shared/widgets/admin_shell_layout.dart';
import 'package:agrimotion/core/services/cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';
  
  final cacheService = await CacheService.init();
  
  runApp(
    ProviderScope(
      overrides: [
        cacheServiceProvider.overrideWithValue(cacheService),
      ],
      child: const AgriMotionApp(),
    ),
  );
}

/// Root application widget for AgriMotion Smart Agriculture IoT Platform.
///
/// Uses [ProviderScope] for Riverpod state management and
/// [GoRouter] for declarative routing with auth guards.
class AgriMotionApp extends ConsumerWidget {
  const AgriMotionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'AgriMotion - Smart Agriculture IoT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
