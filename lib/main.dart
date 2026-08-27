import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations_plus/flutter_localizations_plus.dart';
import 'package:flutter_localizations_plus/localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openair/config/config.dart';

import 'package:openair/home.dart';
import 'package:openair/providers/audio_provider.dart';
import 'package:openair/providers/locale_provider.dart';
import 'package:openair/providers/openair_provider.dart';
import 'package:openair/services/audio_handler.dart';
import 'package:openair/services/background_service.dart';
import 'package:openair/services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:openair/config/firebase_config.dart';
import 'package:theme_provider/theme_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background task worker
  if (Platform.isAndroid || Platform.isIOS) {
    await Workmanager().initialize(
      callbackDispatcher,
    );
  }

  // Configure audio session for media playback
  final session = await AudioSession.instance;

  await session.configure(const AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.music,
      usage: AndroidAudioUsage.media,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
  ));

  // Initialize audio service for background playback
  await AudioService.init(
    builder: () => getAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.liquidhive.openair',
      androidNotificationChannelName: 'OpenAir Audio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
    ),
  );

  // Enable edge-to-edge with transparent system bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));

  // Request notification permission for Android 13+
  if (Platform.isAndroid) {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  // Load saved language BEFORE setting up Translations
  await Hive.initFlutter('OpenAir/.hive_config');
  final box = await Hive.openBox('openAirBox');
  final settings = box.get('userInterface');
  final language = settings?['language'] ?? 'English';

  Translations.support([
    Localization.ar_AE,
    Localization.de_DE,
    Localization.es_ES,
    Localization.en_US,
    Localization.fr_FR,
    Localization.he_IL,
    Localization.it_IT,
    Localization.ja_JP,
    Localization.ko_KR,
    Localization.nl_NL,
    Localization.pt_PT,
    Localization.ru_RU,
    Localization.sv_SE,
    Localization.zh_CN,
  ]);

  // Set the language BEFORE runApp
  _setLanguage(language);

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      minimumSize: Size(720, 600),
      title: 'OpenAir',
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseConfig.isAvailable = true;
  } catch (e) {
    debugPrint('Firebase not available: $e');
    FirebaseConfig.isAvailable = false;
  }

  runApp(ProviderScope(child: const MyApp()));
}

void _setLanguage(String language) {
  // Update the config
  languageConfig = language;

  switch (language) {
    case 'English':
      Translations.changeLanguage(Localization.en_US);
      break;
    case 'Spanish':
      Translations.changeLanguage(Localization.es_ES);
      break;
    case 'French':
      Translations.changeLanguage(Localization.fr_FR);
      break;
    case 'German':
      Translations.changeLanguage(Localization.de_DE);
      break;
    case 'Italian':
      Translations.changeLanguage(Localization.it_IT);
      break;
    case 'Portuguese':
      Translations.changeLanguage(Localization.pt_PT);
      break;
    case 'Russian':
      Translations.changeLanguage(Localization.ru_RU);
      break;
    case 'Chinese':
      Translations.changeLanguage(Localization.zh_CN);
      break;
    case 'Japanese':
      Translations.changeLanguage(Localization.ja_JP);
      break;
    case 'Korean':
      Translations.changeLanguage(Localization.ko_KR);
      break;
    case 'Arabic':
      Translations.changeLanguage(Localization.ar_AE);
      break;
    case 'Hebrew':
      Translations.changeLanguage(Localization.he_IL);
      break;
    case 'Dutch':
      Translations.changeLanguage(Localization.nl_NL);
      break;
    case 'Swedish':
      Translations.changeLanguage(Localization.sv_SE);
      break;
    default:
      Translations.changeLanguage(Localization.en_US);
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  Future<void>? _initialization;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initialization ??= _initApp();
  }

  Future<void> _initApp() async {
    if (mounted) await ref.read(openAirProvider).initial(context);
    if (mounted) await ref.read(audioProvider).initAudio(context);
    if (mounted) await ref.read(notificationProvider).init(context);
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      // Default theme - will be overridden by _loadSavedTheme() if needed
      defaultThemeId: 'blue_accent_light_medium',
      saveThemesOnChange: true,
      loadThemeOnInit: false, // We'll load manually to handle Auto mode
      themes: [
        AppTheme(
          id: "blue_accent_light_small",
          description: "Light theme with blue accent",
          data: ThemeData(
            brightness: Brightness.light,
            useMaterial3: true,
            scaffoldBackgroundColor: scaffoldBackgroundColorLight,
            primaryColor: primaryColorLight,
            appBarTheme: appBarThemeLight,
            floatingActionButtonTheme: floatingActionButtonTheme,
            cardColor: cardColorLight,
            colorScheme: colorSchemeLight,
            textTheme: scaleTextTheme(baseTextTheme, 0.875),
            snackBarTheme: snackBarThemeLight,
            listTileTheme: listTileThemeLight,
            dialogTheme: dialogThemeLight,
          ),
        ),
        AppTheme(
          id: "blue_accent_light_medium",
          description: "Light theme with blue accent",
          data: ThemeData(
            brightness: Brightness.light,
            useMaterial3: true,
            scaffoldBackgroundColor: scaffoldBackgroundColorLight,
            primaryColor: primaryColorLight,
            appBarTheme: appBarThemeLight,
            floatingActionButtonTheme: floatingActionButtonTheme,
            cardColor: cardColorLight,
            colorScheme: colorSchemeLight,
            textTheme: scaleTextTheme(baseTextTheme, 1.0),
            snackBarTheme: snackBarThemeLight,
            listTileTheme: listTileThemeLight,
            dialogTheme: dialogThemeLight,
          ),
        ),
        AppTheme(
          id: "blue_accent_light_large",
          description: "Light theme with blue accent",
          data: ThemeData(
            brightness: Brightness.light,
            useMaterial3: true,
            scaffoldBackgroundColor: scaffoldBackgroundColorLight,
            primaryColor: primaryColorLight,
            appBarTheme: appBarThemeLight,
            floatingActionButtonTheme: floatingActionButtonTheme,
            cardColor: cardColorLight,
            colorScheme: colorSchemeLight,
            textTheme: scaleTextTheme(baseTextTheme, 1.2),
            snackBarTheme: snackBarThemeLight,
            listTileTheme: listTileThemeLight,
            dialogTheme: dialogThemeLight,
          ),
        ),
        AppTheme(
          id: "blue_accent_light_extra_large",
          description: "Light theme with blue accent",
          data: ThemeData(
            brightness: Brightness.light,
            useMaterial3: true,
            scaffoldBackgroundColor: scaffoldBackgroundColorLight,
            primaryColor: primaryColorLight,
            appBarTheme: appBarThemeLight,
            floatingActionButtonTheme: floatingActionButtonTheme,
            cardColor: cardColorLight,
            colorScheme: colorSchemeLight,
            textTheme: scaleTextTheme(baseTextTheme, 1.4),
            snackBarTheme: snackBarThemeLight,
            listTileTheme: listTileThemeLight,
            dialogTheme: dialogThemeLight,
          ),
        ),
        AppTheme(
          id: "blue_accent_dark_small",
          description: "Dark theme with blue accent",
          data: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            scaffoldBackgroundColor: scaffoldBackgroundColorDark,
            primaryColor: primaryColorDark,
            appBarTheme: appBarThemeDark,
            floatingActionButtonTheme: floatingActionButtonTheme,
            cardColor: cardColorDark,
            colorScheme: colorSchemeDark,
            textTheme: scaleTextTheme(baseTextTheme, 0.875),
            snackBarTheme: snackBarThemeDark,
            listTileTheme: listTileThemeDark,
            dialogTheme: dialogThemeDark,
          ),
        ),
        AppTheme(
          id: "blue_accent_dark_medium",
          description: "Dark theme with blue accent",
          data: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            scaffoldBackgroundColor: scaffoldBackgroundColorDark,
            primaryColor: primaryColorDark,
            appBarTheme: appBarThemeDark,
            floatingActionButtonTheme: floatingActionButtonTheme,
            cardColor: cardColorDark,
            colorScheme: colorSchemeDark,
            textTheme: scaleTextTheme(baseTextTheme, 1.0),
            snackBarTheme: snackBarThemeDark,
            listTileTheme: listTileThemeDark,
            dialogTheme: dialogThemeDark,
          ),
        ),
        AppTheme(
          id: "blue_accent_dark_large",
          description: "Dark theme with blue accent",
          data: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            scaffoldBackgroundColor: scaffoldBackgroundColorDark,
            primaryColor: primaryColorDark,
            appBarTheme: appBarThemeDark,
            floatingActionButtonTheme: floatingActionButtonTheme,
            cardColor: cardColorDark,
            colorScheme: colorSchemeDark,
            textTheme: scaleTextTheme(baseTextTheme, 1.2),
            snackBarTheme: snackBarThemeDark,
            listTileTheme: listTileThemeDark,
            dialogTheme: dialogThemeDark,
          ),
        ),
        AppTheme(
          id: "blue_accent_dark_extra_large",
          description: "Dark theme with blue accent",
          data: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            scaffoldBackgroundColor: scaffoldBackgroundColorDark,
            primaryColor: primaryColorDark,
            appBarTheme: appBarThemeDark,
            floatingActionButtonTheme: floatingActionButtonTheme,
            cardColor: cardColorDark,
            colorScheme: colorSchemeDark,
            textTheme: scaleTextTheme(baseTextTheme, 1.4),
            snackBarTheme: snackBarThemeDark,
            listTileTheme: listTileThemeDark,
            dialogTheme: dialogThemeDark,
          ),
        ),
      ],
      child: ThemeConsumer(
        child: Builder(
          builder: (themeContext) {
            final themeData = ThemeProvider.themeOf(themeContext).data;

            return _AppHome(
              initialization: _initialization,
              themeData: themeData,
            );
          },
        ),
      ),
    );
  }
}

class _AppHome extends ConsumerStatefulWidget {
  final Future<void>? initialization;
  final ThemeData themeData;

  const _AppHome({
    this.initialization,
    required this.themeData,
  });

  @override
  ConsumerState<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends ConsumerState<_AppHome>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _minDelayPassed = false;
  bool _systemThemeApplied = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Load saved theme
    _loadSavedTheme();

    // Listen for system theme changes
    WidgetsBinding.instance.addObserver(this);

    // Minimum 2 second delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _minDelayPassed = true);
      }
    });
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (mounted) {
      _applySystemTheme();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final audio = ref.read(audioProvider);
      audio.updateHistoryPlaybackPosition();
      audio.savePlayerState();
    }
  }

  void _applySystemTheme() {
    if (!mounted || themeModeConfig != 'System') return;

    final brightness = View.of(context).platformDispatcher.platformBrightness;
    final sizeSuffix = _getSizeSuffix(fontSizeConfig);
    final themeSuffix = brightness == Brightness.dark ? 'dark' : 'light';
    final themeId = 'blue_accent_${themeSuffix}_$sizeSuffix';

    ThemeProvider.controllerOf(context).setTheme(themeId);
  }

  String _getSizeSuffix(String fontSizeFactor) {
    switch (fontSizeFactor) {
      case 'Small':
        return 'small';
      case 'Large':
        return 'large';
      case 'Extra Large':
        return 'extra_large';
      default:
        return 'medium';
    }
  }

  void _loadSavedTheme() async {
    try {
      final box = await Hive.openBox('openAirBox');
      final settings = box.get('userInterface');

      if (settings != null && mounted) {
        final fontSizeFactor = settings['fontSizeFactor'] ?? 'Medium';
        final themeMode = settings['themeMode'] ?? 'System';

        fontSizeConfig = fontSizeFactor;
        themeModeConfig = themeMode;

        String sizeSuffix = _getSizeSuffix(fontSizeFactor);
        String themeSuffix;

        if (themeMode == 'System') {
          final brightness =
              View.of(context).platformDispatcher.platformBrightness;
          themeSuffix = brightness == Brightness.dark ? 'dark' : 'light';
        } else {
          themeSuffix = themeMode == 'Dark' ? 'dark' : 'light';
        }

        final themeId = 'blue_accent_${themeSuffix}_$sizeSuffix';
        ThemeProvider.controllerOf(context).setTheme(themeId);
      }
    } catch (e) {
      debugPrint('Error loading saved theme: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: widget.initialization,
      builder: (context, snapshot) {
        final initDone = snapshot.connectionState == ConnectionState.done;

        // Apply system theme once initialization is done
        if (initDone && _minDelayPassed && mounted && !_systemThemeApplied) {
          _systemThemeApplied = true;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _applySystemTheme());
        }

        // Show splash while: init not done OR min delay not passed
        if (!initDone || !_minDelayPassed) {
          return _buildSplash();
        }

        // Show Home
        final locale = ref.watch(localeProvider);

        return MaterialApp(
          builder: (context, child) {
            // Apply safe area to all routes, but only at the bottom
            // so the status bar remains edge-to-edge
            return SafeArea(
              top: false,
              bottom: true,
              maintainBottomViewPadding: true,
              child: child ?? const SizedBox.shrink(),
            );
          },
          locale: locale,
          supportedLocales: Translations.supportedLocales,
          localizationsDelegates: const [
            LocalizationsPlusDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FallbackCupertinoLocalizationsDelegate()
          ],
          debugShowCheckedModeBanner: false,
          title: 'OpenAir',
          theme: widget.themeData,
          home: Home(),
        );
      },
    );
  }

  Widget _buildSplash() {
    return MaterialApp(
      locale: const Locale('en', 'US'),
      supportedLocales: Translations.supportedLocales,
      localizationsDelegates: const [
        LocalizationsPlusDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FallbackCupertinoLocalizationsDelegate()
      ],
      debugShowCheckedModeBanner: false,
      title: 'OpenAir',
      theme: widget.themeData,
      home: Scaffold(
        backgroundColor: widget.themeData.colorScheme.primary,
        body: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.radio,
                  size: 100,
                  color: widget.themeData.colorScheme.onPrimary,
                ),
                const SizedBox(height: 20),
                Text(
                  'OpenAir',
                  style: widget.themeData.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.themeData.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 40),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.themeData.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
