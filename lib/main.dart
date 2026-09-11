import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/language_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> _requestNotificationPermission() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await messaging.getToken();
      debugPrint('FCM Token: $token');
    }
  } catch (e) {
    debugPrint('Notification permission error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await LanguageService.instance.init();
  await _requestNotificationPermission();
  FirebaseMessaging.onMessage.listen((message) {
    debugPrint('FCM message: ${message.notification?.title}');
  });
  runApp(const HumiAirApp());
}

class HumiAirApp extends StatelessWidget {
  const HumiAirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.instance.currentLanguage,
      builder: (context, currentLang, _) {
        return MaterialApp(
          title: 'HumiAir',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0EA5E9),
              brightness: Brightness.light,
            ),
            textTheme: const TextTheme(
              displayLarge:
                  TextStyle(fontWeight: FontWeight.w200, letterSpacing: 8),
              headlineMedium:
                  TextStyle(fontWeight: FontWeight.w500, letterSpacing: 1),
              bodyMedium: TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconScale;
  late Animation<double> _iconFade;
  late Animation<double> _textFade;
  late Animation<double> _mistFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _iconFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: Curves.easeIn),
      ),
    );

    _iconScale = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _mistFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
      ),
    );

    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.9, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Fast, smooth navigation after 1.5 seconds instead of 4 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const AuthGate(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0F2FE), Color(0xFF7DD3FC), Color(0xFF38BDF8)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _iconScale.value,
                    child: FadeTransition(
                      opacity: _iconFade,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.blue.withValues(alpha: 0.2),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          _MistParticles(progress: _mistFade.value),
                          Icon(
                            Icons.water_drop_rounded,
                            size: 84,
                            color: Colors.white
                                .withValues(alpha: _iconFade.value),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _textFade,
                    child: const Text(
                      'HumiAir',
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w300,
                        color: Color(0xFF0F172A),
                        letterSpacing: 7,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _textFade,
                    child: Text(
                      Tr.smartHumidityControl,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade800.withValues(alpha: 0.8),
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
              const Spacer(flex: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF0F9FF),
            body: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class _MistParticles extends StatelessWidget {
  final double progress;
  const _MistParticles({required this.progress});

  @override
  Widget build(BuildContext context) {
    final random = Random(42);
    final particles = List.generate(20, (i) {
      final angle = random.nextDouble() * 2 * pi;
      final distance = 60 + random.nextDouble() * 80;
      final size = 3 + random.nextDouble() * 6;
      final delay = random.nextDouble() * 0.3;
      return _Particle(
        angle: angle,
        distance: distance,
        size: size,
        delay: delay,
        progress: progress,
      );
    });

    return Stack(
      alignment: Alignment.center,
      children: particles,
    );
  }
}

class _Particle extends StatelessWidget {
  final double angle;
  final double distance;
  final double size;
  final double delay;
  final double progress;

  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final adjustedProgress = (progress - delay).clamp(0, 1);
    if (adjustedProgress <= 0) return const SizedBox.shrink();

    final x = cos(angle) * distance * adjustedProgress;
    final y = -sin(angle) * distance * adjustedProgress - 20 * adjustedProgress;
    final opacity = (1 - adjustedProgress) * 0.6;

    return Transform.translate(
      offset: Offset(x, y),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.shade600.withValues(alpha: opacity),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade300.withValues(alpha: opacity * 0.5),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
