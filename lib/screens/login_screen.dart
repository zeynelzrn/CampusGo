import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_screen.dart';
import '../services/auth_service.dart';
import '../repositories/profile_repository.dart';
import '../widgets/custom_notification.dart';
import 'home_screen.dart';
import 'create_profile_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  
  // FADE VE SLIDE ANİMASYONLARI
  late AnimationController _animationController;
  late AnimationController _buttonAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _buttonAnimationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonAnimationController, curve: Curves.easeInOut),
    );
    
    _animationController.forward();
    
    Future.delayed(Duration(milliseconds: 800), () {
      _buttonAnimationController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _buttonAnimationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Modern bildirim göster
  void _showModernNotification({
    required String message,
    required bool isSuccess,
    IconData? icon,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _ModernNotification(
        message: message,
        isSuccess: isSuccess,
        icon: icon,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);

    // Otomatik kapat
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  // Şifremi unuttum dialogu
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    bool isResetting = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2C60).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: Color(0xFFFF2C60),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Şifremi Unuttum',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'E-posta adresinize şifre sıfırlama linki göndereceğiz.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.poppins(fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'E-posta Adresi',
                    hintText: 'ornek@universite.edu.tr',
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Color(0xFFFF2C60),
                    ),
                    labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF2C60),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'İptal',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isResetting
                    ? null
                    : () async {
                        if (resetEmailController.text.trim().isEmpty) {
                          CustomNotification.error(
                            context,
                            'Lütfen e-posta adresinizi girin',
                          );
                          return;
                        }

                        setDialogState(() => isResetting = true);

                        final result = await _authService.resetPassword(
                          email: resetEmailController.text.trim(),
                        );

                        setDialogState(() => isResetting = false);

                        if (context.mounted) {
                          Navigator.pop(context);

                          if (result['success']) {
                            CustomNotification.success(
                              context,
                              'Şifre Sıfırlama',
                              subtitle: result['message'],
                            );
                          } else {
                            CustomNotification.error(
                              context,
                              result['error'] ?? 'Bir hata oluştu',
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2C60),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: isResetting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Gönder',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFFF8EDE3),
              Color(0xFFFDF6F0),
              Color(0xFFF0F4F8),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Dekoratif şekiller
            Positioned(
              top: -60,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFBA93).withOpacity(0.2),
                      Color(0xFFFF2C60).withOpacity(0.15),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: 200,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFF6B9D).withOpacity(0.1),
                      Color(0xFFFFBA93).withOpacity(0.15),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            
            // Ana içerik - FADE + BAŞLIK SLIDE
            SafeArea(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Geri butonu - animasyonsuz
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFFF2C60).withOpacity(0.15),
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(
                                  Icons.arrow_back_ios_new,
                                  color: Color(0xFFFF2C60),
                                  size: 22,
                                ),
                              ),
                            ),
                            
                            SizedBox(height: 40),
                            
                            // Başlık - SLIDE ANİMASYONU
                            Transform.translate(
                              offset: Offset(0, 30 * _slideAnimation.value),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Seni Özlemişiz! 💫',
                                    style: GoogleFonts.poppins(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      foreground: Paint()
                                        ..shader = LinearGradient(
                                          colors: [
                                            Color(0xFFFF2C60),
                                            Color(0xFFFF4081),
                                            Color(0xFFFF6B9D),
                                          ],
                                        ).createShader(Rect.fromLTWH(0.0, 0.0, 300.0, 80.0)),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFFFF2C60).withOpacity(0.1),
                                          Color(0xFFFF6B9D).withOpacity(0.05),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Arkadaşların seni bekliyor • Hadi geri dön!',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 50),
                            
                            // Form alanları - SABİT BOYUTLAR
// E-posta alanı - BORDER DÜZELTİLDİ + UYARI SİSTEMİ
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: 'E-posta Adresi',
        hintText: 'ornek@universite.edu.tr',
        prefixIcon: Container(
          margin: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFFFF2C60).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.alternate_email_rounded, color: Color(0xFFFF2C60), size: 22),
        ),
        labelStyle: GoogleFonts.poppins(color: Colors.grey[600], fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontWeight: FontWeight.w400),
        filled: true,
        fillColor: Colors.white.withOpacity(0.95),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Color(0xFFFF2C60), width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.red, width: 2.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        errorStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.red,
          fontWeight: FontWeight.w500,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'E-posta adresi gerekli';
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Geçerli bir e-posta adresi girin';
        return null;
      },
    ),
  ],
),

SizedBox(height: 20),

// Şifre alanı - BORDER DÜZELTİLDİ + UYARI SİSTEMİ
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: 'Şifre',
        hintText: 'Şifrenizi girin',
        prefixIcon: Container(
          margin: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFFFF2C60).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.lock_outline_rounded, color: Color(0xFFFF2C60), size: 22),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Color(0xFFFF2C60),
            size: 22,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        labelStyle: GoogleFonts.poppins(color: Colors.grey[600], fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontWeight: FontWeight.w400),
        filled: true,
        fillColor: Colors.white.withOpacity(0.95),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Color(0xFFFF2C60), width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.red, width: 2.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        errorStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.red,
          fontWeight: FontWeight.w500,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Şifre gerekli';
        return null;
      },
    ),
  ],
),

SizedBox(height: 30),
                            
                            // BENİ HATIRLA - MODERN VERSİYON (saçmalık mesajlar kaldırıldı)
                            Row(
                              children: [
                                // Sol - Beni hatırla (modern, temiz)
                                Expanded(
                                  flex: 3,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _rememberMe = !_rememberMe);
                                    },
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 250),
                                      height: 58,
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: _rememberMe 
                                          ? Color(0xFFFF2C60).withOpacity(0.1)
                                          : Colors.white.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _rememberMe 
                                            ? Color(0xFFFF2C60).withOpacity(0.4)
                                            : Colors.grey.withOpacity(0.3),
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          AnimatedContainer(
                                            duration: Duration(milliseconds: 250),
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: _rememberMe ? Color(0xFFFF2C60) : Colors.grey[300],
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: _rememberMe 
                                              ? Icon(Icons.check, size: 16, color: Colors.white)
                                              : null,
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Beni hatırla',
                                              style: GoogleFonts.poppins(
                                                fontSize: 15,
                                                color: _rememberMe ? Color(0xFFFF2C60) : Colors.grey[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                
                                SizedBox(width: 12),
                                
                                // Sağ - Şifremi unuttum (daha geniş)
                                Expanded(
                                  flex: 2,
                                  child: GestureDetector(
                                    onTap: () => _showForgotPasswordDialog(),
                                    child: Container(
                                      height: 58,
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFFFF2C60).withOpacity(0.1),
                                            Color(0xFFFF6B9D).withOpacity(0.05),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Color(0xFFFF2C60).withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Şifremi unuttum',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12.5,
                                            color: Color(0xFFFF2C60),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            SizedBox(height: 50),
                            
                            // GIRIŞ YAP BUTONU - PULSE + SHIMMER
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: 1.0 + (0.02 * _pulseAnimation.value),
                                  child: Container(
                                    width: double.infinity,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      gradient: LinearGradient(
                                        colors: [Color(0xFFFF2C60), Color(0xFFFF4081), Color(0xFFFF6B9D)],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFFFF2C60).withOpacity(0.5 + (0.1 * _pulseAnimation.value)),
                                          blurRadius: 25 + (5 * _pulseAnimation.value),
                                          offset: Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        // SHIMMER EFEKTİ
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(18),
                                              gradient: LinearGradient(
                                                begin: Alignment(-1.0 + (2.0 * _pulseAnimation.value), 0.0),
                                                end: Alignment(1.0 + (2.0 * _pulseAnimation.value), 0.0),
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.white.withOpacity(0.2 * _pulseAnimation.value),
                                                  Colors.transparent,
                                                ],
                                                stops: [0.0, 0.5, 1.0],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Material + InkWell ile güzel tıklama efekti
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _isLoading ? null : () async {
                                              if (_formKey.currentState!.validate()) {
                                                setState(() => _isLoading = true);

                                                final result = await _authService.login(
                                                  email: _emailController.text.trim(),
                                                  password: _passwordController.text,
                                                );

                                                setState(() => _isLoading = false);

                                                if (result['success']) {
                                                  // "Beni hatırla" seçeneğini kaydet
                                                  final prefs = await SharedPreferences.getInstance();
                                                  await prefs.setBool('remember_me', _rememberMe);

                                                  if (mounted) {
                                                    _showModernNotification(
                                                      message: 'Hoş geldin! Profil kontrol ediliyor...',
                                                      isSuccess: true,
                                                      icon: Icons.favorite_rounded,
                                                    );

                                                    // Profil kontrolü yap
                                                    final profileRepository = ProfileRepository();
                                                    final hasProfile = await profileRepository.hasProfile();

                                                    await Future.delayed(const Duration(milliseconds: 500));

                                                    if (mounted) {
                                                      if (hasProfile) {
                                                        Navigator.pushReplacement(
                                                          context,
                                                          MaterialPageRoute(builder: (context) => const HomeScreen()),
                                                        );
                                                      } else {
                                                        Navigator.pushReplacement(
                                                          context,
                                                          MaterialPageRoute(builder: (context) => const CreateProfileScreen()),
                                                        );
                                                      }
                                                    }
                                                  }
                                                } else {
                                                  if (mounted) {
                                                    _showModernNotification(
                                                      message: result['error'],
                                                      isSuccess: false,
                                                    );
                                                  }
                                                }
                                              }
                                            },
                                            borderRadius: BorderRadius.circular(18),
                                            splashColor: Colors.white.withOpacity(0.3),
                                            highlightColor: Colors.white.withOpacity(0.1),
                                            child: SizedBox(
                                              width: double.infinity,
                                              height: 58,
                                              child: Center(
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    if (_isLoading) ...[
                                                      const SizedBox(
                                                        width: 22,
                                                        height: 22,
                                                        child: CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2.5,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        'Giriş yapılıyor...',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ] else ...[
                                                      const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 22),
                                                      const SizedBox(width: 10),
                                                      Text(
                                                        'Giriş Yap',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            SizedBox(height: 50),
                            
                            // ALT KISIM - BÜYÜK HESAP OLUŞTUR BUTONU
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) => RegisterScreen(),
                                    transitionDuration: Duration(milliseconds: 350),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      var curvedAnimation = CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.fastOutSlowIn,
                                      );
                                      
                                      var loginSlide = Tween<Offset>(
                                        begin: Offset.zero,
                                        end: Offset(-1.0, 0.0),
                                      ).animate(curvedAnimation);
                                      
                                      var registerSlide = Tween<Offset>(
                                        begin: Offset(1.0, 0.0),
                                        end: Offset.zero,
                                      ).animate(curvedAnimation);
                                      
                                      return Stack(
                                        children: [
                                          SlideTransition(
                                            position: loginSlide,
                                            child: LoginScreen(),
                                          ),
                                          SlideTransition(
                                            position: registerSlide,
                                            child: child,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.9),
                                      Colors.white.withOpacity(0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Color(0xFFFF2C60).withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFFFF2C60).withOpacity(0.15),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFFFF2C60), Color(0xFFFF6B9D)],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.person_add_rounded, color: Colors.white, size: 24),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Henüz hesabın yok mu?',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            'Hemen Aramıza Katıl!',
                                            style: GoogleFonts.poppins(
                                              fontSize: 17,
                                              color: Color(0xFFFF2C60),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Color(0xFFFF2C60),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            SizedBox(height: 60),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modern Bildirim Widget'ı
class _ModernNotification extends StatefulWidget {
  final String message;
  final bool isSuccess;
  final IconData? icon;
  final VoidCallback onDismiss;

  const _ModernNotification({
    required this.message,
    required this.isSuccess,
    this.icon,
    required this.onDismiss,
  });

  @override
  State<_ModernNotification> createState() => _ModernNotificationState();
}

class _ModernNotificationState extends State<_ModernNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: -100, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Otomatik kapanma animasyonu
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
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
    final Color primaryColor = widget.isSuccess
        ? const Color(0xFFFF2C60)
        : const Color(0xFFE53935);

    final Color bgColor = widget.isSuccess
        ? const Color(0xFFFFF0F3)
        : const Color(0xFFFFEBEE);

    final IconData iconData = widget.icon ??
        (widget.isSuccess ? Icons.check_circle_rounded : Icons.error_rounded);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 20 + _slideAnimation.value,
          left: 20,
          right: 20,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {
                    _controller.reverse().then((_) => widget.onDismiss());
                  },
                  onHorizontalDragEnd: (details) {
                    _controller.reverse().then((_) => widget.onDismiss());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Animated Icon Container
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween(begin: 0, end: 1),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: widget.isSuccess
                                        ? [
                                            const Color(0xFFFF2C60),
                                            const Color(0xFFFF6B9D),
                                          ]
                                        : [
                                            const Color(0xFFE53935),
                                            const Color(0xFFEF5350),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  iconData,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        // Message
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.isSuccess ? 'Başarılı!' : 'Hata!',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.message,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Close hint
                        Icon(
                          Icons.close_rounded,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}