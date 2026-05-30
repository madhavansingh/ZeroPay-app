import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/global_providers.dart';

class ZeroPayApp extends ConsumerWidget {
  const ZeroPayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'ZeroPay - Blockchain Commerce OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme, // Defaulting both to light theme to honor the soft-light Lumina design tokens
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
