import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/profile_repository.dart';
import 'welcome_screen.dart';
import 'main_screen.dart';
import 'create_profile_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late AnimationController _dotsAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String _statusText = 'Yükleniyor...';

  @override
  void initState() {
    super.initState();

    // Logo animasyonu
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Nokta animasyonu (ayrı controller)
    _dotsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    ));

    _logoAnimationController.forward();
    _dotsAnimationController.repeat();

    // Otomatik giriş kontrolü yap
    _checkAuthAndProfile();
  }

  Future<void> _checkAuthAndProfile() async {
    // Minimum splash süresi
    await Future.delayed(const Duration(seconds: 2));

    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? false;
      final currentUser = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      // Kullanıcı giriş yapmamış veya "beni hatırla" seçmemiş
      if (currentUser == null || !rememberMe) {
        _navigateTo(WelcomeScreen());
        return;
      }

      // Kullanıcı giriş yapmış, profil kontrolü yap
      setState(() => _statusText = 'Profil kontrol ediliyor...');

      final profileRepository = ProfileRepository();
      final hasProfile = await profileRepository.hasProfile();

      if (!mounted) return;

      if (hasProfile) {
        // Profil var, ana sayfaya git
        _navigateTo(const MainScreen());
      } else {
        // Profil yok, profil oluşturma ekranına git
        _navigateTo(const CreateProfileScreen());
      }
    } catch (e) {
      // Hata durumunda welcome ekranına git
      debugPrint('Splash error: $e');
      if (mounted) {
        _navigateTo(WelcomeScreen());
      }
    }
  }

  void _navigateTo(Widget destination) {
    Navigator.pushReplacement(
      context,
      _createRoute(destination),
    );
  }

  Route<void> _createRoute(Widget destination) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _dotsAnimationController,
      builder: (context, child) {
        double delay = index * 0.3;
        double animValue = (_dotsAnimationController.value + delay) % 1.0;

        // Daha smooth scale hesaplaması
        double scale;
        if (animValue < 0.5) {
          scale = 0.5 + (animValue * 1.0); // 0.5'den 1.0'a
        } else {
          scale = 1.0 - ((animValue - 0.5) * 1.0); // 1.0'dan 0.5'e
        }

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _dotsAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5C6BC0),
      body: Center(
        child: AnimatedBuilder(
          animation: _logoAnimationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Image.asset(
                        'assets/images/campus_logo_c.png',
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 50),

                    // 3 nokta animasyonu - smooth
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildDot(0),
                        const SizedBox(width: 10),
                        _buildDot(1),
                        const SizedBox(width: 10),
                        _buildDot(2),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Text(
                      _statusText,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
