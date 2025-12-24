import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'register_screen.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _buttonAnimationController;
  late AnimationController _backgroundController;
  late AnimationController _floatingController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _logoAnimation;
  late Animation<double> _breathingAnimation;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _buttonAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Arka plan için sürekli animasyon
    _backgroundController = AnimationController(
      duration: Duration(seconds: 8),
      vsync: this,
    );
    
    // Floating animasyon
    _floatingController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    
    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController, 
        curve: Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );
    
    // Nefes alma animasyonu - logo için
    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    );
    
    // Floating animasyon
    _floatingAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );
    
    _animationController.forward();
    
    // Buton animasyonunu gecikmeli başlat
    Future.delayed(Duration(milliseconds: 600), () {
      _buttonAnimationController.forward();
    });
    
    // Sürekli animasyonları başlat
    Future.delayed(Duration(milliseconds: 1500), () {
      _backgroundController.repeat(reverse: true);
      _floatingController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _buttonAnimationController.dispose();
    _backgroundController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFDF6F0),
              Color(0xFFF8EDE3),
              Color(0xFFFDF6F0),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animasyonlu dekoratif şekiller
            AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return Positioned(
                  top: -100 + (20 * _breathingAnimation.value),
                  left: -50 + (10 * _breathingAnimation.value),
                  child: Transform.rotate(
                    angle: _backgroundController.value * 0.5,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Color(0xFFFF2C60).withOpacity(0.15 * _breathingAnimation.value),
                            Color(0xFFFFBA93).withOpacity(0.25 * _breathingAnimation.value),
                            Colors.transparent,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return Positioned(
                  bottom: -80 - (15 * _breathingAnimation.value),
                  right: -60 - (15 * _breathingAnimation.value),
                  child: Transform.rotate(
                    angle: -_backgroundController.value * 0.3,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Color(0xFFFFBA93).withOpacity(0.35 * _breathingAnimation.value),
                            Color(0xFFFF2C60).withOpacity(0.15 * _breathingAnimation.value),
                            Colors.transparent,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // Floating partikül efektleri
            ...List.generate(6, (index) => 
              AnimatedBuilder(
                animation: _floatingController,
                builder: (context, child) {
                  double offset = _floatingAnimation.value + (index * 3);
                  return Positioned(
                    top: 100 + (index * 80) + offset,
                    right: 20 + (index % 2) * 40,
                    child: Opacity(
                      opacity: 0.3,
                      child: Container(
                        width: 4 + (index % 3) * 2,
                        height: 4 + (index % 3) * 2,
                        decoration: BoxDecoration(
                          color: Color(0xFFFF2C60),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFFF2C60).withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Ana içerik
            FadeTransition(
              opacity: _fadeAnimation,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Spacer(flex: 2),
                      
                      // Logo bölümü - Canlı animasyonlarla
                      AnimatedBuilder(
                        animation: Listenable.merge([_logoAnimation, _breathingAnimation]),
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoAnimation.value * _breathingAnimation.value,
                            child: Transform.rotate(
                              angle: (1 - _logoAnimation.value) * 0.1,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Parlayan halka efekti
                                  Container(
                                    width: 340,
                                    height: 340,
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        colors: [
                                          Color(0xFFFF2C60).withOpacity(0.1 * _breathingAnimation.value),
                                          Color(0xFFFF6B9D).withOpacity(0.05 * _breathingAnimation.value),
                                          Colors.transparent,
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  // Fade gölge - beyaz
                                  Transform.translate(
                                    offset: Offset(0, -15),
                                    child: Container(
                                      width: 320,
                                      height: 320,
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          colors: [
                                            Colors.white,
                                            Colors.white,
                                            Colors.white.withOpacity(0.6),
                                            Colors.white.withOpacity(0.0),
                                          ],
                                          stops: [0.0, 0.5, 0.8, 1.0],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  // Ana logo
                                  Container(
                                    width: 320,
                                    height: 320,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(160),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFFFFFFFF).withOpacity(0.2),
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(160),
                                      child: Image.asset(
                                        'assets/images/campus_logo_welcome.png',
                                        width: 320,
                                        height: 320,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      
                      Spacer(flex: 1),
                      
                      // Alt başlık - Floating animasyon
                      AnimatedBuilder(
                        animation: _floatingAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _floatingAnimation.value * 0.3),
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: Column(
                                children: [
                                  Text(
                                    'Hoş Geldin!',
                                    style: GoogleFonts.poppins(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      foreground: Paint()
                                        ..shader = LinearGradient(
                                          colors: [
                                            Color(0xFFFF2C60),
                                            Color(0xFFFF4081),
                                            Color(0xFFE91E63),
                                          ],
                                        ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Kampüs hayatında yeni dostluklar\nve güzel anılar seni bekliyor',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w400,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      
                      Spacer(flex: 1),
                      
                      // Butonlar bölümü - Hover efektleri eklenmiş
                      AnimatedBuilder(
                        animation: _buttonAnimationController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, 30 * (1 - Curves.easeOutBack.transform(_buttonAnimationController.value))),
                            child: Transform.scale(
                              scale: 0.8 + (0.2 * Curves.elasticOut.transform(_buttonAnimationController.value)),
                              child: Opacity(
                                opacity: _buttonAnimationController.value,
                                child: Column(
                                  children: [
                                    // Giriş Yap butonu - Parlayan efekt
                                    AnimatedBuilder(
                                      animation: _buttonAnimationController,
                                      builder: (context, child) {
                                        double buttonDelay = (_buttonAnimationController.value - 0.2).clamp(0.0, 1.0) / 0.8;
                                        return Transform.translate(
                                          offset: Offset(-20 * (1 - Curves.easeOutCubic.transform(buttonDelay)), 0),
                                          child: Transform.rotate(
                                            angle: -0.05 * (1 - buttonDelay),
                                            child: Opacity(
                                              opacity: buttonDelay,
                                              child: _buildAnimatedButton(
                                                'Giriş Yap',
                                                Icons.login,
                                                true,
                                                () {
                                                  Navigator.push(
                                                    context,
                                                    _createPageRoute(LoginScreen()),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    
                                    SizedBox(height: 16),
                                    
                                    // Üye Ol butonu
                                    AnimatedBuilder(
                                      animation: _buttonAnimationController,
                                      builder: (context, child) {
                                        double buttonDelay2 = (_buttonAnimationController.value - 0.4).clamp(0.0, 1.0) / 0.6;
                                        return Transform.translate(
                                          offset: Offset(20 * (1 - Curves.easeOutCubic.transform(buttonDelay2)), 0),
                                          child: Transform.rotate(
                                            angle: 0.05 * (1 - buttonDelay2),
                                            child: Opacity(
                                              opacity: buttonDelay2,
                                              child: _buildAnimatedButton(
                                                'Üye Ol',
                                                Icons.person_add,
                                                false,
                                                () {
                                                  Navigator.push(
                                                    context,
                                                    _createPageRoute(RegisterScreen()),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      Spacer(flex: 1),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAnimatedButton(String text, IconData icon, bool isPrimary, VoidCallback onPressed) {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isPrimary ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF2C60),
                Color(0xFFFF6B9D),
                Color(0xFFFF8BA7),
              ],
            ) : null,
            color: isPrimary ? null : Colors.white.withOpacity(0.9),
            border: isPrimary ? null : Border.all(
              color: Color(0xFFFF2C60),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isPrimary
                  ? Color(0xFFFF2C60).withOpacity(0.4 * _breathingAnimation.value)
                  : Colors.black.withOpacity(0.05 * _breathingAnimation.value),
                blurRadius: isPrimary ? 20 + (5 * _breathingAnimation.value) : 10,
                offset: Offset(0, isPrimary ? 10 : 4),
                spreadRadius: isPrimary ? 2 : 0,
              ),
              if (isPrimary)
                BoxShadow(
                  color: Colors.white.withOpacity(0.3 * _breathingAnimation.value),
                  blurRadius: 5,
                  offset: Offset(0, -2),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(16),
              splashColor: isPrimary
                  ? Colors.white.withOpacity(0.3)
                  : Color(0xFFFF2C60).withOpacity(0.2),
              highlightColor: isPrimary
                  ? Colors.white.withOpacity(0.1)
                  : Color(0xFFFF2C60).withOpacity(0.1),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: isPrimary ? Colors.white : Color(0xFFFF2C60),
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Text(
                      text,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isPrimary ? Colors.white : Color(0xFFFF2C60),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  PageRouteBuilder _createPageRoute(Widget destination) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      transitionDuration: Duration(milliseconds: 350),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.fastOutSlowIn,
        );
        
        var welcomeSlide = Tween<Offset>(
          begin: Offset.zero,
          end: Offset(-1.0, 0.0),
        ).animate(curvedAnimation);
        
        var destinationSlide = Tween<Offset>(
          begin: Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curvedAnimation);
        
        return Stack(
          children: [
            SlideTransition(
              position: welcomeSlide,
              child: WelcomeScreen(),
            ),
            SlideTransition(
              position: destinationSlide,
              child: child,
            ),
          ],
        );
      },
    );
  }
}