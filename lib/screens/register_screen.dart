import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'create_profile_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  
  late AnimationController _animationController;
  late AnimationController _buttonAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _buttonGlowAnimation;
  late Animation<double> _buttonRotateAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _buttonAnimationController = AnimationController(
      duration: Duration(milliseconds: 300), // Hızlı geçiş
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _buttonScaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _buttonAnimationController, curve: Curves.easeOutBack),
    );
    
    _buttonGlowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonAnimationController, curve: Curves.easeOut),
    );
    
    _buttonRotateAnimation = Tween<double>(begin: 0.0, end: 0.02).animate(
      CurvedAnimation(parent: _buttonAnimationController, curve: Curves.elasticOut),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _buttonAnimationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  void _toggleTermsAgreement(bool? value) {
    setState(() {
      _agreeToTerms = value ?? false;
    });

    if (_agreeToTerms) {
      _buttonAnimationController.forward();
    } else {
      _buttonAnimationController.reverse(); // Hızlı deaktivasyon
    }
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
            // Dekoratif şekiller
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFF2C60).withOpacity(0.1),
                      Color(0xFFFFBA93).withOpacity(0.2),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -60,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFBA93).withOpacity(0.3),
                      Color(0xFFFF2C60).withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            
            // Ana içerik
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    // Üst kısım - Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Geri butonu
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(
                                    Icons.arrow_back_ios_new,
                                    color: Color(0xFFFF2C60),
                                    size: 20,
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: 40),
                              
                              // Başlık bölümü
                              Center(
                                child: Column(
                                  children: [
                                    Text(
                                      'Aramıza Katıl',
                                      style: GoogleFonts.poppins(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        foreground: Paint()
                                          ..shader = LinearGradient(
                                            colors: [
                                              Color(0xFFFF2C60),
                                              Color(0xFFFF6B9D),
                                            ],
                                          ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Kampüs hayatında yeni başlangıçlar seni bekliyor',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              SizedBox(height: 50),
                              
                              // Form alanları
                              _buildModernTextField(
                                controller: _emailController,
                                label: 'Üniversite E-postası',
                                hint: 'ornek@universite.edu.tr',
                                icon: Icons.alternate_email,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'E-posta adresi gerekli';
                                  }
                                  if (!value.endsWith('.edu.tr')) {
                                    return 'Sadece .edu.tr uzantılı e-postalar kabul edilir';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'Geçerli bir e-posta adresi girin';
                                  }
                                  return null;
                                },
                              ),
                              
                              SizedBox(height: 20),
                              
                              _buildModernTextField(
                                controller: _passwordController,
                                label: 'Şifre',
                                hint: 'En az 6 karakter',
                                icon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: Color(0xFFFF2C60),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Şifre gerekli';
                                  }
                                  if (value.length < 6) {
                                    return 'Şifre en az 6 karakter olmalı';
                                  }
                                  return null;
                                },
                              ),
                              
                              SizedBox(height: 20),
                              
                              _buildModernTextField(
                                controller: _confirmPasswordController,
                                label: 'Şifre Onayı',
                                hint: 'Şifrenizi tekrar girin',
                                icon: Icons.lock_outline,
                                obscureText: _obscureConfirmPassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                    color: Color(0xFFFF2C60),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword = !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Şifre onayı gerekli';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Şifreler eşleşmiyor';
                                  }
                                  return null;
                                },
                              ),
                              
                              SizedBox(height: 30),
                              
                              // KVKK Onayı
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _agreeToTerms ? Color(0xFFFF2C60) : Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        gradient: _agreeToTerms ? LinearGradient(
                                          colors: [Color(0xFFFF2C60), Color(0xFFFF6B9D)],
                                        ) : null,
                                        color: _agreeToTerms ? null : Colors.grey[300],
                                      ),
                                      child: Checkbox(
                                        value: _agreeToTerms,
                                        onChanged: _toggleTermsAgreement,
                                        activeColor: Colors.transparent,
                                        checkColor: Colors.white,
                                        side: BorderSide.none,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _toggleTermsAgreement(!_agreeToTerms),
                                        child: RichText(
                                          text: TextSpan(
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                            children: [
                                              TextSpan(text: 'KVKK kapsamında '),
                                              TextSpan(
                                                text: 'Aydınlatma Metni',
                                                style: TextStyle(
                                                  color: Color(0xFFFF2C60),
                                                  fontWeight: FontWeight.w600,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                              TextSpan(text: "'ni okudum ve "),
                                              TextSpan(
                                                text: 'Kullanım Şartları',
                                                style: TextStyle(
                                                  color: Color(0xFFFF2C60),
                                                  fontWeight: FontWeight.w600,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                              TextSpan(text: "'nı kabul ediyorum."),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Alt kısım - Sabit butonlar
                    Container(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Üye ol butonu - Ultra modern animasyon
                          AnimatedBuilder(
                            animation: _buttonAnimationController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _buttonScaleAnimation.value,
                                child: Transform.rotate(
                                  angle: _buttonRotateAnimation.value,
                                  child: Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: _agreeToTerms ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFFF2C60),
                                          Color(0xFFFF6B9D),
                                          Color(0xFFFF8BA7),
                                        ],
                                      ) : LinearGradient(
                                        colors: [Colors.grey[300]!, Colors.grey[400]!],
                                      ),
                                      boxShadow: [
                                        if (_agreeToTerms) ...[
                                          BoxShadow(
                                            color: Color(0xFFFF2C60).withOpacity(0.4 * _buttonGlowAnimation.value),
                                            blurRadius: 20 + (10 * _buttonGlowAnimation.value),
                                            offset: Offset(0, 10),
                                            spreadRadius: 2 * _buttonGlowAnimation.value,
                                          ),
                                          BoxShadow(
                                            color: Colors.white.withOpacity(0.3 * _buttonGlowAnimation.value),
                                            blurRadius: 5,
                                            offset: Offset(0, -2),
                                          ),
                                        ],
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        // Parıltı efekti
                                        if (_agreeToTerms)
                                          Positioned.fill(
                                            child: AnimatedBuilder(
                                              animation: _buttonAnimationController,
                                              builder: (context, child) {
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(16),
                                                    gradient: LinearGradient(
                                                      begin: Alignment(-1.0 + (2.0 * _buttonGlowAnimation.value), 0.0),
                                                      end: Alignment(1.0 + (2.0 * _buttonGlowAnimation.value), 0.0),
                                                      colors: [
                                                        Colors.transparent,
                                                        Colors.white.withOpacity(0.3 * _buttonGlowAnimation.value),
                                                        Colors.transparent,
                                                      ],
                                                      stops: [0.0, 0.5, 1.0],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        
                                        // Ana buton
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _agreeToTerms && !_isLoading ? () async {
                                              if (_formKey.currentState!.validate()) {
                                                setState(() => _isLoading = true);

                                                final result = await _authService.register(
                                                  email: _emailController.text.trim(),
                                                  password: _passwordController.text,
                                                );

                                                setState(() => _isLoading = false);

                                                if (result['success']) {
                                                  _buttonAnimationController.reverse().then((_) {
                                                    _buttonAnimationController.forward();
                                                  });

                                                  if (mounted) {
                                                    _showModernNotification(
                                                      message: 'Hesabın başarıyla oluşturuldu! Hoş geldin!',
                                                      isSuccess: true,
                                                      icon: Icons.celebration_rounded,
                                                    );

                                                    // Kısa gecikme ile yönlendir
                                                    await Future.delayed(const Duration(milliseconds: 800));

                                                    if (mounted) {
                                                      Navigator.pushReplacement(
                                                        context,
                                                        MaterialPageRoute(builder: (context) => const CreateProfileScreen()),
                                                      );
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
                                            } : null,
                                            borderRadius: BorderRadius.circular(16),
                                            splashColor: Colors.white.withOpacity(0.3),
                                            highlightColor: Colors.white.withOpacity(0.1),
                                            child: SizedBox(
                                              width: double.infinity,
                                              height: 56,
                                              child: Center(
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    if (_isLoading) ...[
                                                      const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Kaydediliyor...',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ] else if (_agreeToTerms) ...[
                                                      const Icon(
                                                        Icons.rocket_launch,
                                                        color: Colors.white,
                                                        size: 22,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Text(
                                                        'Hesap Oluştur',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ] else ...[
                                                      Text(
                                                        'Hesap Oluştur',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.grey[600],
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
                                ),
                              );
                            },
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Giriş yap linki
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.poppins(fontSize: 16),
                                children: [
                                  TextSpan(
                                    text: 'Zaten hesabın var mı? ',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  TextSpan(
                                    text: 'Giriş Yap',
                                    style: TextStyle(
                                      color: Color(0xFFFF2C60),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFF2C60).withOpacity(0.1),
                  Color(0xFFFF6B9D).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Color(0xFFFF2C60), size: 20),
          ),
          suffixIcon: suffixIcon,
          labelStyle: GoogleFonts.poppins(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey[400],
            fontWeight: FontWeight.w400,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Color(0xFFFF2C60),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.red[400]!,
              width: 1,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator,
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
                                        ? [const Color(0xFFFF2C60), const Color(0xFFFF6B9D)]
                                        : [const Color(0xFFE53935), const Color(0xFFEF5350)],
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
                                child: Icon(iconData, color: Colors.white, size: 24),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
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
                        Icon(Icons.close_rounded, color: Colors.grey[400], size: 20),
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