import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isBlocked = false;        // Did I block them?
  bool _isBlockedByTarget = false; // Did they block me?
  String? _error;

  /// Check if viewing own profile (Preview Mode)
  bool get _isOwnProfile => _userService.currentUserId == widget.userId;

  @override
  void initState() {
    super.initState();
    _loadProfileAndBlockStatus();
  }

  Future<void> _loadProfileAndBlockStatus() async {
    try {
      debugPrint('Loading profile for user: ${widget.userId}');
      debugPrint('Is own profile (Preview Mode): $_isOwnProfile');

      // If viewing own profile, skip block checks
      if (_isOwnProfile) {
        final profile = await _chatService.getUserProfile(widget.userId);
        if (mounted) {
          setState(() {
            _profile = profile;
            _isLoading = false;
            if (profile == null) {
              _error = 'Profil bulunamadi';
            }
          });
        }
        return;
      }

      // Load profile and BOTH block statuses in parallel
      final results = await Future.wait([
        _chatService.getUserProfile(widget.userId),
        _userService.isUserBlocked(widget.userId),    // Did I block them?
        _userService.isBlockedByUser(widget.userId),  // Did they block me?
      ]);

      final profile = results[0] as UserProfile?;
      final isBlocked = results[1] as bool;
      final isBlockedByTarget = results[2] as bool;

      debugPrint('Profile loaded: ${profile?.name}');
      debugPrint('I blocked them: $isBlocked');
      debugPrint('They blocked me: $isBlockedByTarget');

      if (mounted) {
        setState(() {
          _profile = profile;
          _isBlocked = isBlocked;
          _isBlockedByTarget = isBlockedByTarget;
          _isLoading = false;

          // If profile is null OR they blocked me, show appropriate error
          if (profile == null) {
            _error = 'Profil bulunamadi';
          } else if (isBlockedByTarget) {
            // They blocked me - show access denied
            _error = 'Bu profile erisim yok';
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Profil yuklenirken hata olustu';
        });
      }
    }
  }

  Future<void> _unblockUser() async {
    setState(() => _isLoading = true);

    final success = await _userService.unblockUser(widget.userId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) {
          _isBlocked = false;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                success
                    ? 'Engel kaldirildi'
                    : 'Engel kaldirilamadi',
                style: GoogleFonts.poppins(),
              ),
            ],
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? _buildLoadingState()
          : _isBlockedByTarget
              ? _buildAccessDeniedState() // They blocked me - can't see their profile
              : _error != null
                  ? _buildErrorState()
                  : _isBlocked
                      ? _buildBlockedState() // I blocked them - show unblock option
                      : _buildProfileContent(),
    );
  }

  /// Build Access Denied state when the TARGET user has blocked US
  /// This ensures mutual invisibility - they can't see us, we can't see them
  Widget _buildAccessDeniedState() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF5C6BC0)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profil',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Access denied icon
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.visibility_off_rounded,
                  size: 80,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Profil Goruntulenemiyor',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bu kullanicinin profili su anda\ngoruntulenemiyor.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              // Back button
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                label: Text(
                  'Geri Don',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedState() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF5C6BC0)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Engellenen Kullanici',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (value) {
              if (value == 'unblock') {
                _showUnblockDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'unblock',
                child: Row(
                  children: [
                    const Icon(Icons.lock_open, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Engeli Kaldir',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Blocked icon
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  size: 80,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Bu Kullanici Engellendi',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bu kullanicinin profilini goremez ve\nsize mesaj atamazsiniz.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              // Unblock button
              ElevatedButton.icon(
                onPressed: _showUnblockDialog,
                icon: const Icon(Icons.lock_open, color: Colors.white),
                label: Text(
                  'Engeli Kaldir',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 16),
              // Back button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Geri Don',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnblockDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_open, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Engeli Kaldir',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Bu kullanicinin engelini kaldirmak istediginize emin misiniz?\n\nEngel kaldirildiktan sonra bu kisi size mesaj atabilir ve profilinizi gorebilir.',
          style: GoogleFonts.poppins(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Iptal',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _unblockUser();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Engeli Kaldir',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Bir hata olustu',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C6BC0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Geri Don',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    final profile = _profile!;

    return CustomScrollView(
      slivers: [
        // App Bar with Photo
        SliverAppBar(
          expandedHeight: 400,
          pinned: true,
          backgroundColor: const Color(0xFF5C6BC0),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Profile Photo
                if (profile.photos.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: profile.photos.first,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFF5C6BC0),
                      child: const Icon(Icons.person, size: 100, color: Colors.white),
                    ),
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.person, size: 100, color: Colors.white),
                  ),

                // Gradient overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // Name and Age
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${profile.name}, ${profile.age}',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Aktif',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (profile.university.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.school, color: Colors.white70, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                profile.university,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Profile Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preview Mode Banner (when viewing own profile)
                if (_isOwnProfile) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF5C6BC0).withValues(alpha: 0.1),
                          const Color(0xFF7986CB).withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF5C6BC0).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5C6BC0).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.visibility_rounded,
                            color: Color(0xFF5C6BC0),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Onizleme Modu',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF5C6BC0),
                                ),
                              ),
                              Text(
                                'Profiliniz baskalarinin gozunden boyle gorunuyor',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Bio Section
                if (profile.bio.isNotEmpty) ...[
                  _buildSectionTitle('Hakkinda'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      profile.bio,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Education Section
                if (profile.university.isNotEmpty || profile.department.isNotEmpty) ...[
                  _buildSectionTitle('Egitim'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (profile.university.isNotEmpty)
                          _buildInfoRow(Icons.school, 'Universite', profile.university),
                        if (profile.department.isNotEmpty) ...[
                          const Divider(height: 24),
                          _buildInfoRow(Icons.book, 'Bolum', profile.department),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Interests Section
                if (profile.interests.isNotEmpty) ...[
                  _buildSectionTitle('Ilgi Alanlari'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: profile.interests.map((interest) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            interest,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // More Photos Section
                if (profile.photos.length > 1) ...[
                  _buildSectionTitle('Fotograflar'),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: profile.photos.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _showFullScreenPhoto(profile.photos[index]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: profile.photos[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.error),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF5C6BC0).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF5C6BC0), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFullScreenPhoto(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
