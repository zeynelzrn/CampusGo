import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'create_profile_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false; // EULA & Gizlilik (Zorunlu)
  bool _agreeToCommercialNotifications = false; // ETK - Ticari İleti (İsteğe Bağlı)
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
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300), // Hızlı geçiş
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _buttonScaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
          parent: _buttonAnimationController, curve: Curves.easeOutBack),
    );

    _buttonGlowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _buttonAnimationController, curve: Curves.easeOut),
    );

    _buttonRotateAnimation = Tween<double>(begin: 0.0, end: 0.02).animate(
      CurvedAnimation(
          parent: _buttonAnimationController, curve: Curves.elasticOut),
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

  void _toggleCommercialNotifications(bool? value) {
    setState(() {
      _agreeToCommercialNotifications = value ?? false;
    });
  }

  // EULA - Sıfır Tolerans Metni (Apple UGC Compliance)
  void _showEulaDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sürükleme çubuğu
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Başlık
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.gavel_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Kullanıcı Sözleşmesi (EULA)',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2D3142),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Sıfır Tolerans İçeriği
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFB74D).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFFF9800),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sıfır Tolerans Politikası',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'CampusGo\'da taciz, küfür, çıplaklık ve nefret söylemine sıfır tolerans gösterilir. Bu kuralları ihlal eden hesaplar kalıcı olarak engellenir.',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Uygulamayı kullanarak Apple Standart EULA şartlarını kabul etmiş sayılırsınız.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Kapat butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C6BC0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Anladım',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Gizlilik Politikası
  void _showPrivacyPolicyDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sürükleme çubuğu
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Başlık
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.privacy_tip_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Gizlilik Politikası',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2D3142),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Kişisel verileriniz KVKK kapsamında korunmaktadır. Verileriniz yalnızca uygulama hizmetlerini sunmak için kullanılır ve üçüncü taraflarla izinsiz paylaşılmaz.',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Detaylı bilgi için Aydınlatma Metni\'ni inceleyebilirsiniz.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C6BC0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Anladım',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Ticari Elektronik İleti Bilgilendirmesi (ETK)
  void _showCommercialNotificationInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sürükleme çubuğu
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Başlık
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ticari Elektronik İleti',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2D3142),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // İçerik
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF81C784).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF4CAF50),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Size sadece önemli güncellemeleri göndereceğiz',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Onay verdiğinizde şunları alabilirsiniz:',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoItem(Icons.local_offer_rounded, 'Özel kampanya ve fırsatlar'),
                _buildInfoItem(Icons.new_releases_rounded, 'Yeni özellik duyuruları'),
                _buildInfoItem(Icons.event_rounded, 'Kampüs etkinlik bildirimleri'),
                const SizedBox(height: 16),
                Text(
                  'İstediğiniz zaman ayarlardan iptal edebilirsiniz.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C6BC0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Anladım',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF5C6BC0)),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // Modern onay kutusu widget'ı
  Widget _buildAgreementCheckbox({
    required bool isChecked,
    required ValueChanged<bool?> onChanged,
    required bool isRequired,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isChecked
              ? const Color(0xFF5C6BC0)
              : (isRequired ? Colors.grey[300]! : Colors.grey[200]!),
          width: isChecked ? 1.5 : 1,
        ),
        boxShadow: isChecked
            ? [
                BoxShadow(
                  color: const Color(0xFF5C6BC0).withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          GestureDetector(
            onTap: () => onChanged(!isChecked),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: isChecked
                    ? const LinearGradient(
                        colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                      )
                    : null,
                color: isChecked ? null : Colors.grey[200],
                border: isChecked
                    ? null
                    : Border.all(color: Colors.grey[400]!, width: 1.5),
              ),
              child: isChecked
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                child,
                if (isRequired) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Zorunlu',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF5F8FF), // Soft buz mavisi
              Color(0xFFE8F0FE), // Açık indigo tonu
              Color(0xFFF0F4FF), // Ferah mavi-beyaz
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Dekoratif şekiller - Modern mavi tonlar
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF5C6BC0).withValues(alpha: 0.15),
                      const Color(0xFF42A5F5).withValues(alpha: 0.10),
                      Colors.transparent,
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
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7C4DFF).withValues(alpha: 0.18),
                      const Color(0xFF00BCD4).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Sağ alt köşe blob
            Positioned(
              bottom: 150,
              right: -80,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7986CB).withValues(alpha: 0.12),
                      const Color(0xFF64B5F6).withValues(alpha: 0.08),
                      Colors.transparent,
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
                        padding: const EdgeInsets.all(24.0),
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
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new,
                                    color: Color(0xFF5C6BC0),
                                    size: 20,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

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
                                          ..shader = const LinearGradient(
                                            colors: [
                                              Color(0xFF5C6BC0),
                                              Color(0xFF7986CB),
                                            ],
                                          ).createShader(Rect.fromLTWH(
                                              0.0, 0.0, 200.0, 70.0)),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
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

                              const SizedBox(height: 24),

                              // Form alanları
                              _buildModernTextField(
                                controller: _emailController,
                                label: 'E-posta',
                                hint: 'ornek@universite.edu.tr',
                                icon: Icons.alternate_email,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'E-posta adresi gerekli';
                                  }
                                  // Standart email format kontrolü
                                  if (!RegExp(
                                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(value)) {
                                    return 'Geçerli bir e-posta adresi girin';
                                  }
                                  // Üniversite email kontrolü (.edu veya .edu.tr)
                                  final lowerEmail = value.toLowerCase();
                                  if (!lowerEmail.endsWith('.edu.tr') &&
                                      !lowerEmail.endsWith('.edu')) {
                                    return 'Sadece üniversite e-posta adresiyle (.edu veya .edu.tr) kayıt olabilirsiniz.';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              _buildModernTextField(
                                controller: _passwordController,
                                label: 'Şifre',
                                hint: 'En az 8 karakter, büyük/küçük harf ve rakam',
                                icon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: const Color(0xFF5C6BC0),
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
                                  // Güçlü şifre validasyonu
                                  if (value.length < 8) {
                                    return 'Şifre en az 8 karakter olmalı';
                                  }
                                  if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                    return 'Şifre en az 1 büyük harf içermeli';
                                  }
                                  if (!RegExp(r'[a-z]').hasMatch(value)) {
                                    return 'Şifre en az 1 küçük harf içermeli';
                                  }
                                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                                    return 'Şifre en az 1 rakam içermeli';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              _buildModernTextField(
                                controller: _confirmPasswordController,
                                label: 'Şifre Onayı',
                                hint: 'Şifrenizi tekrar girin',
                                icon: Icons.lock_outline,
                                obscureText: _obscureConfirmPassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: const Color(0xFF5C6BC0),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
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

                              const SizedBox(height: 20),

                              // 1. Checkbox - EULA & Gizlilik (Zorunlu)
                              _buildAgreementCheckbox(
                                isChecked: _agreeToTerms,
                                onChanged: _toggleTermsAgreement,
                                isRequired: true,
                                child: RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      height: 1.4,
                                    ),
                                    children: [
                                      WidgetSpan(
                                        child: GestureDetector(
                                          onTap: _showEulaDialog,
                                          child: Text(
                                            'Kullanıcı Sözleşmesi (EULA)',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: const Color(0xFF5C6BC0),
                                              fontWeight: FontWeight.w600,
                                              decoration: TextDecoration.underline,
                                              decorationColor: const Color(0xFF5C6BC0),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const TextSpan(text: ' ve '),
                                      WidgetSpan(
                                        child: GestureDetector(
                                          onTap: _showPrivacyPolicyDialog,
                                          child: Text(
                                            'Gizlilik Politikası',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: const Color(0xFF5C6BC0),
                                              fontWeight: FontWeight.w600,
                                              decoration: TextDecoration.underline,
                                              decorationColor: const Color(0xFF5C6BC0),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const TextSpan(text: '\'nı okudum, kabul ediyorum.'),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // 2. Checkbox - Ticari Elektronik İleti / ETK (İsteğe Bağlı)
                              _buildAgreementCheckbox(
                                isChecked: _agreeToCommercialNotifications,
                                onChanged: _toggleCommercialNotifications,
                                isRequired: false,
                                child: RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      height: 1.4,
                                    ),
                                    children: [
                                      const TextSpan(text: 'Kampanya, duyuru ve bilgilendirmelerden haberdar olmak için '),
                                      WidgetSpan(
                                        child: GestureDetector(
                                          onTap: _showCommercialNotificationInfo,
                                          child: Text(
                                            'Ticari Elektronik İleti',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: const Color(0xFF5C6BC0),
                                              fontWeight: FontWeight.w600,
                                              decoration: TextDecoration.underline,
                                              decorationColor: const Color(0xFF5C6BC0),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const TextSpan(text: ' almayı kabul ediyorum.'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Alt kısım - Sabit butonlar
                    Container(
                      padding: const EdgeInsets.all(24.0),
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
                                      gradient: _agreeToTerms
                                          ? const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFF5C6BC0),
                                                Color(0xFF7986CB),
                                                Color(0xFF9FA8DA),
                                              ],
                                            )
                                          : LinearGradient(
                                              colors: [
                                                Colors.grey[300]!,
                                                Colors.grey[400]!
                                              ],
                                            ),
                                      boxShadow: [
                                        if (_agreeToTerms) ...[
                                          BoxShadow(
                                            color: const Color(0xFF5C6BC0)
                                                .withOpacity(0.4 *
                                                    _buttonGlowAnimation.value),
                                            blurRadius: 20 +
                                                (10 *
                                                    _buttonGlowAnimation.value),
                                            offset: const Offset(0, 10),
                                            spreadRadius:
                                                2 * _buttonGlowAnimation.value,
                                          ),
                                          BoxShadow(
                                            color: Colors.white.withOpacity(
                                                0.3 *
                                                    _buttonGlowAnimation.value),
                                            blurRadius: 5,
                                            offset: const Offset(0, -2),
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
                                              animation:
                                                  _buttonAnimationController,
                                              builder: (context, child) {
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    gradient: LinearGradient(
                                                      begin: Alignment(
                                                          -1.0 +
                                                              (2.0 *
                                                                  _buttonGlowAnimation
                                                                      .value),
                                                          0.0),
                                                      end: Alignment(
                                                          1.0 +
                                                              (2.0 *
                                                                  _buttonGlowAnimation
                                                                      .value),
                                                          0.0),
                                                      colors: [
                                                        Colors.transparent,
                                                        Colors.white
                                                            .withOpacity(0.3 *
                                                                _buttonGlowAnimation
                                                                    .value),
                                                        Colors.transparent,
                                                      ],
                                                      stops: const [
                                                        0.0,
                                                        0.5,
                                                        1.0
                                                      ],
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
                                            onTap: _agreeToTerms && !_isLoading
                                                ? () async {
                                                    if (_formKey.currentState!
                                                        .validate()) {
                                                      setState(() =>
                                                          _isLoading = true);

                                                      final result =
                                                          await _authService
                                                              .register(
                                                        email: _emailController
                                                            .text
                                                            .trim(),
                                                        password:
                                                            _passwordController
                                                                .text,
                                                        isCommercialNotificationsEnabled:
                                                            _agreeToCommercialNotifications,
                                                      );

                                                      setState(() =>
                                                          _isLoading = false);

                                                      if (result['success']) {
                                                        _buttonAnimationController
                                                            .reverse()
                                                            .then((_) {
                                                          _buttonAnimationController
                                                              .forward();
                                                        });

                                                        if (mounted) {
                                                          _showModernNotification(
                                                            message:
                                                                'Hesabın başarıyla oluşturuldu! Şimdi profilini oluştur.',
                                                            isSuccess: true,
                                                            icon: Icons
                                                                .celebration_rounded,
                                                          );

                                                          // Kısa gecikme ile CreateProfileScreen'e yönlendir
                                                          await Future.delayed(
                                                              const Duration(
                                                                  milliseconds:
                                                                      800));

                                                          if (mounted) {
                                                            Navigator
                                                                .pushReplacement(
                                                              context,
                                                              MaterialPageRoute(
                                                                  builder:
                                                                      (context) =>
                                                                          const CreateProfileScreen()),
                                                            );
                                                          }
                                                        }
                                                      } else {
                                                        if (mounted) {
                                                          _showModernNotification(
                                                            message:
                                                                result['error'],
                                                            isSuccess: false,
                                                          );
                                                        }
                                                      }
                                                    }
                                                  }
                                                : null,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            splashColor:
                                                Colors.white.withOpacity(0.3),
                                            highlightColor:
                                                Colors.white.withOpacity(0.1),
                                            child: SizedBox(
                                              width: double.infinity,
                                              height: 56,
                                              child: Center(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    if (_isLoading) ...[
                                                      const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Kaydediliyor...',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w600,
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
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ] else ...[
                                                      Text(
                                                        'Hesap Oluştur',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Colors.grey[600],
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

                          const SizedBox(height: 16),

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
                                  const TextSpan(
                                    text: 'Giriş Yap',
                                    style: TextStyle(
                                      color: Color(0xFF5C6BC0),
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
            offset: const Offset(0, 4),
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
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF5C6BC0).withOpacity(0.1),
                  const Color(0xFF7986CB).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF5C6BC0), size: 20),
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
            borderSide: const BorderSide(
              color: Color(0xFF5C6BC0),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    final Color primaryColor =
        widget.isSuccess ? const Color(0xFF5C6BC0) : const Color(0xFFE53935);

    final Color bgColor =
        widget.isSuccess ? const Color(0xFFFFF0F3) : const Color(0xFFFFEBEE);

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
                                        ? [
                                            const Color(0xFF5C6BC0),
                                            const Color(0xFF7986CB)
                                          ]
                                        : [
                                            const Color(0xFFE53935),
                                            const Color(0xFFEF5350)
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
                                child: Icon(iconData,
                                    color: Colors.white, size: 24),
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
                        Icon(Icons.close_rounded,
                            color: Colors.grey[400], size: 20),
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
