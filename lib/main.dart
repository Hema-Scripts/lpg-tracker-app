// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_navigation.dart';
import 'services/sms_service.dart';
import 'services/notification_service.dart';
import 'services/prediction_service.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFFE8581A),
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const LpgTrackerApp());
}

class LpgTrackerApp extends StatelessWidget {
  const LpgTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LPG Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFE8581A),
        useMaterial3: true,
        fontFamily: 'Noto Sans',
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const _Splash(),
    );
  }
}

class _Splash extends StatefulWidget {
  const _Splash();

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  static const _orange = Color(0xFFE8581A);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Initialize services
    await DatabaseService().database;
    await NotificationService().initialize();

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;

    if (onboardingDone) {
      // Re-initialize SMS listener
      final smsService = SmsService();
      await smsService.initialize();

      // Check if we need to show gas warning (predict per the default
      // connection — pooling durations across different connections, which
      // may be different cylinder types/companies, would give a meaningless
      // blended average).
      final defaultConnection = await DatabaseService().getDefaultConnection();
      final prediction = await PredictionService().predict(connectionId: defaultConnection?.id);
      if (prediction.shouldBookSoon && prediction.daysRemaining != null) {
        await NotificationService().showGasWarning(prediction.daysRemaining!);
      }
    }

    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => onboardingDone
              ? const MainNavigation()
              : const OnboardingScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _orange,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text('🛢️', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'LPG Tracker',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Smart cylinder tracking for India',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
