import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_branding.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/providers.dart';
import 'presentation/widgets/app_ceramic_screen.dart';

class AudioMixerApp extends ConsumerWidget {
  const AudioMixerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final useDarkTheme = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            platformBrightness == Brightness.dark);
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          useDarkTheme ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          useDarkTheme ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          useDarkTheme ? AppTheme.darkBg : AppTheme.bg,
      systemNavigationBarIconBrightness: useDarkTheme
          ? Brightness.light
          : Brightness.dark,
    );
    SystemChrome.setSystemUIOverlayStyle(overlay);

    return MaterialApp.router(
      title: AppBranding.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const AppCeramicPageBackdrop(),
              child ?? const SizedBox.shrink(),
            ],
          ),
        );
      },
    );
  }
}
