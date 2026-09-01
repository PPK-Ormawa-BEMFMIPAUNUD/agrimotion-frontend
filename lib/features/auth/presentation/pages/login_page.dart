import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:agrimotion/core/theme/colors.dart';
import 'package:agrimotion/features/auth/presentation/controllers/auth_controller.dart';

/// Admin Login Page for AgriMotion IoT Agriculture Management Portal.
///
/// Features a responsive split layout on desktop screens with a decorative
/// branding panel, and a full-width centered card on mobile devices.
/// Connects to [authProvider] for session state management and navigation.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final FocusNode _emailFocusNode;
  late final FocusNode _passwordFocusNode;

  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// Validates and submits login form credentials to [AuthNotifier].
  Future<void> _handleLogin() async {
    // Dismiss active keyboard
    FocusScope.of(context).unfocus();

    // Clear any previous error before validation
    ref.read(authProvider.notifier).clearError();

    if (_formKey.currentState?.validate() ?? false) {
      final success = await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
          
      if (!success && mounted) {
        final errorMsg = ref.read(authProvider).errorMessage ?? 'Email atau password salah';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    errorMsg,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.dangerRose,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for authentication changes and navigate when authenticated
    ref.listen<AuthState>(authProvider, (AuthState? previous, AuthState next) {
      if (next.status == AuthStatus.authenticated || next.isAuthenticated) {
        if (mounted) {
          context.go('/admin/overview');
        }
      }
    });

    final AuthState authState = ref.watch(authProvider);
    final Size screenSize = MediaQuery.sizeOf(context);
    final bool isDesktop = screenSize.width >= 960;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: isDesktop
            ? _buildDesktopLayout(context, authState)
            : _buildMobileLayout(context, authState),
      ),
    );
  }

  // ===========================================================================
  // DESKTOP SPLIT LAYOUT
  // ===========================================================================

  Widget _buildDesktopLayout(BuildContext context, AuthState authState) {
    return Row(
      children: <Widget>[
        // Left Branding Panel (Decorative agriculture & IoT showcase)
        Expanded(
          flex: 5,
          child: _buildBrandingPanel(context),
        ),

        // Right Form Panel
        Expanded(
          flex: 6,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _buildLoginFormCard(context, authState, isDesktop: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MOBILE FULL-WIDTH LAYOUT
  // ===========================================================================

  Widget _buildMobileLayout(BuildContext context, AuthState authState) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: _buildLoginFormCard(context, authState, isDesktop: false),
        ),
      ),
    );
  }

  // ===========================================================================
  // BRANDING PANEL (DESKTOP)
  // ===========================================================================

  Widget _buildBrandingPanel(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF042F1A),
            Color(0xFF0A5531),
            Color(0xFF0F7646),
            Color(0xFF16A34A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: <Widget>[
          // Background ambient circles for visual depth
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -40,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.leafGreen.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            top: 240,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),

          // Main decorative content
          Padding(
            padding: const EdgeInsets.all(48.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Top Brand Logo Row
                Row(
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'AGRI-MOTION',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Smart Agriculture & IoT Automation',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(flex: 2),

                // Hero Headline & Tagline
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.sensors_rounded,
                        color: Color(0xFF86EFAC),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Portal Manajemen & Telemetri Terpusat',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF86EFAC),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Transformasi Pertanian Presisi Berbasis IoT',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Monitoring telemetri sensor tanah real-time, otomasi irigasi pintar, dan manajemen demplot pertanian terintegrasi dalam satu platform.',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.55,
                  ),
                ),

                const SizedBox(height: 36),

                // Feature Highlights List
                _buildBrandingFeatureItem(
                  icon: Icons.speed_rounded,
                  title: 'Telemetri Real-time Cepat',
                  subtitle:
                      'Pantau kelembapan, suhu, pH & NPK tanah dengan latensi rendah via MQTT & SSE.',
                ),
                const SizedBox(height: 18),
                _buildBrandingFeatureItem(
                  icon: Icons.water_drop_rounded,
                  title: 'Otomasi Irigasi & Pompa',
                  subtitle:
                      'Kendali aktuator jarak jauh dengan mode manual dan algoritma cerdas berbasis sensor.',
                ),
                const SizedBox(height: 18),
                _buildBrandingFeatureItem(
                  icon: Icons.notifications_active_rounded,
                  title: 'Peringatan Dini Cerdas',
                  subtitle:
                      'Deteksi anomali tanah dan cuaca seketika untuk menjaga produktivitas panen optimal.',
                ),

                const Spacer(flex: 3),

                // Bottom Footer Attribution
                Container(
                  padding: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.school_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PPKO BEM FMIPA UNUD',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'v2.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF86EFAC),
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // LOGIN FORM CARD
  // ===========================================================================

  Widget _buildLoginFormCard(
    BuildContext context,
    AuthState authState, {
    required bool isDesktop,
  }) {
    final bool isLoading = authState.isLoading;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 36 : 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Mobile Brand Logo Badge (Shown only on mobile layout)
            if (!isDesktop) ...<Widget>[
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primaryEmerald.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'AGRI-MOTION',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],

            // Form Title & Subtitle
            Text(
              'Portal Admin',
              style: TextStyle(
                fontSize: isDesktop ? 26 : 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: isDesktop ? TextAlign.left : TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Masukkan email dan kata sandi untuk mengelola portal telemetri dan sistem pertanian.',
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
              textAlign: isDesktop ? TextAlign.left : TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Error Alert Banner
            if (authState.hasError && authState.errorMessage != null) ...<Widget>[
              _buildErrorBanner(authState.errorMessage!),
              const SizedBox(height: 18),
            ],

            // Email Input Field
            const Text(
              'Alamat Email',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !isLoading,
              autofillHints: const <String>[
                AutofillHints.email,
                AutofillHints.username,
              ],
              decoration: InputDecoration(
                hintText: 'admin@agrimotion.id',
                prefixIcon: const Icon(
                  Icons.alternate_email_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryEmerald,
                    width: 1.8,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.dangerRose),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.dangerRose,
                    width: 1.8,
                  ),
                ),
              ),
              validator: (String? value) {
                final String input = value?.trim() ?? '';
                if (input.isEmpty) {
                  return 'Email tidak boleh kosong';
                }
                final RegExp emailRegex = RegExp(
                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                );
                if (!emailRegex.hasMatch(input)) {
                  return 'Format email tidak valid (contoh: admin@agrimotion.id)';
                }
                return null;
              },
              onFieldSubmitted: (_) {
                _passwordFocusNode.requestFocus();
              },
            ),

            const SizedBox(height: 18),

            // Password Input Field
            const Text(
              'Kata Sandi',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: !_isPasswordVisible,
              textInputAction: TextInputAction.done,
              enabled: !isLoading,
              autofillHints: const <String>[AutofillHints.password],
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: _isPasswordVisible
                      ? 'Sembunyikan kata sandi'
                      : 'Tampilkan kata sandi',
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                filled: true,
                fillColor: AppColors.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryEmerald,
                    width: 1.8,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.dangerRose),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.dangerRose,
                    width: 1.8,
                  ),
                ),
              ),
              validator: (String? value) {
                final String input = value ?? '';
                if (input.isEmpty) {
                  return 'Kata sandi tidak boleh kosong';
                }
                if (input.length < 6) {
                  return 'Kata sandi minimal 6 karakter';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleLogin(),
            ),

            const SizedBox(height: 24),

            // Submit Button ("Masuk")
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryEmerald,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primaryEmerald.withValues(alpha: 0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.login_rounded, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Masuk',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),


            const SizedBox(height: 32),

            // Footer link / help
            Center(
              child: Text(
                '© 2026 PPKO BEM FMIPA Universitas Udayana',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ERROR BANNER WIDGET
  // ===========================================================================

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerRose.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.dangerRose.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline_rounded,
              color: AppColors.dangerRose,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.dangerRose,
                height: 1.4,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              ref.read(authProvider.notifier).clearError();
            },
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.dangerRose,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
