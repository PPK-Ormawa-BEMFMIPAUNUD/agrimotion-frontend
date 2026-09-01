import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agrimotion/core/theme/colors.dart';
import 'package:agrimotion/core/network/api_client.dart';
import 'package:agrimotion/core/constants/api_constants.dart';
import 'package:agrimotion/core/services/cache_service.dart';

/// Public-facing landing page for AgriMotion Smart Agriculture IoT platform.
///
/// Provides an interactive, modern, single-page presentation showcasing:
/// - Sticky Responsive Navigation Bar with Mobile Drawer
/// - Hero Section with live IoT telemetry preview and call-to-actions
/// - Keunggulan / Key Features grid
/// - Public Statistics & Demplot Showcase (Bunga Pacah, Sawi, Cabai)
/// - PPKO BEM FMIPA Universitas Udayana Program & Team Section
/// - Comprehensive Footer with contact information and admin navigation
class LandingPage extends ConsumerStatefulWidget {
  /// Creates the [LandingPage] widget.
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  final ScrollController _scrollController = ScrollController();

  // Section global keys for smooth scrolling navigation
  final GlobalKey _berandaKey = GlobalKey();
  final GlobalKey _fiturKey = GlobalKey();
  final GlobalKey _statistikKey = GlobalKey();
  final GlobalKey _timKey = GlobalKey();
  final GlobalKey _kontakKey = GlobalKey();

  bool _isScrolled = false;
  bool _mobileMenuOpen = false;
  
  bool _isLoadingData = true;
  int _totalDataPoints = 189126; // Default to previous static value, will be updated
  int _activeSensorNodes = 3;
  final int _activeDemplots = 3;
  Map<String, dynamic>? _latestTelemetry;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLiveData();
    });
  }

  Future<void> _fetchLiveData() async {
    if (!mounted) return;
    
    final cacheService = ref.read(cacheServiceProvider);
    
    // 1. Load from cache immediately
    final cachedHistory = cacheService.getCacheData('landing_totalDataPoints');
    if (cachedHistory != null) _totalDataPoints = cachedHistory;
    
    final cachedNodes = cacheService.getCacheData('landing_activeSensorNodes');
    if (cachedNodes != null) _activeSensorNodes = cachedNodes;
    
    final cachedTelemetry = cacheService.getCacheData('landing_latestTelemetry');
    if (cachedTelemetry != null) {
      _latestTelemetry = cachedTelemetry;
      _isLoadingData = false;
      setState(() {});
    }

    // 2. Fetch from API in background (Revalidate)
    try {
      final apiClient = ref.read(apiClientProvider);
      
      // Fetch Total Data Points
      final historyResponse = await apiClient.get(Uri.parse('${ApiConstants.telemetryHistoryEndpoint}?limit=1'), requiresAuth: false);
      final historyData = apiClient.parseJson(historyResponse);
      if (historyData['success'] == true) {
        _totalDataPoints = historyData['meta']['total'] ?? _totalDataPoints;
        await cacheService.setCacheData('landing_totalDataPoints', _totalDataPoints);
      }
      
      // Fetch Active Sensor Nodes
      final devicesResponse = await apiClient.get(Uri.parse(ApiConstants.devicesStatusEndpoint), requiresAuth: false);
      final devicesData = apiClient.parseJson(devicesResponse);
      _activeSensorNodes = devicesData['total'] ?? _activeSensorNodes;
      await cacheService.setCacheData('landing_activeSensorNodes', _activeSensorNodes);
      
      // Fetch Latest Telemetry
      final telemetryResponse = await apiClient.get(Uri.parse(ApiConstants.latestTelemetryEndpoint), requiresAuth: false);
      final telemetryData = apiClient.parseJson(telemetryResponse);
      if (telemetryData['success'] == true && telemetryData['data'] != null) {
        final List<dynamic> data = telemetryData['data'];
        if (data.isNotEmpty) {
          _latestTelemetry = data.first;
          await cacheService.setCacheData('landing_latestTelemetry', _latestTelemetry);
        }
      }
    } catch (e) {
      // Ignored for landing page to avoid breaking UI on network error
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final bool scrolled = _scrollController.offset > 40;
    if (scrolled != _isScrolled) {
      setState(() {
        _isScrolled = scrolled;
      });
    }
  }

  void _scrollToSection(GlobalKey key) {
    setState(() {
      _mobileMenuOpen = false;
    });

    final BuildContext? targetContext = key.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: <Widget>[
          // Main Scrollable Content
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Top spacing to prevent navbar overlap
                const SizedBox(height: 72),

                // 1. Hero Section
                Container(
                  key: _berandaKey,
                  child: _HeroSection(
                    onExplorePressed: () => _scrollToSection(_statistikKey),
                    onLoginPressed: () => _scrollToSection(_fiturKey),
                    latestTelemetry: _latestTelemetry,
                    isLoading: _isLoadingData,
                  ),
                ),

                // 2. Features / Keunggulan Section
                Container(
                  key: _fiturKey,
                  child: const _FeaturesSection(),
                ),

                // 3. Public Stats & Demplot Binaan Section
                Container(
                  key: _statistikKey,
                  child: _StatsAndDemplotSection(
                    totalDataPoints: _totalDataPoints,
                    activeSensorNodes: _activeSensorNodes,
                    activeDemplots: _activeDemplots,
                  ),
                ),

                // 4. Team & Organization Section (PPKO BEM FMIPA UNUD)
                Container(
                  key: _timKey,
                  child: const _TeamSection(),
                ),

                // 5. Footer Section
                Container(
                  key: _kontakKey,
                  child: _Footer(
                    onNavHome: () => _scrollToSection(_berandaKey),
                    onNavFeatures: () => _scrollToSection(_fiturKey),
                    onNavStats: () => _scrollToSection(_statistikKey),
                    onNavTeam: () => _scrollToSection(_timKey),
                    onNavAdmin: () => _scrollToSection(_fiturKey),
                  ),
                ),
              ],
            ),
          ),

          // Sticky Top Navigation Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _StickyNavbar(
              isScrolled: _isScrolled,
              isMobile: isMobile,
              isMenuOpen: _mobileMenuOpen,
              onToggleMenu: () {
                setState(() {
                  _mobileMenuOpen = !_mobileMenuOpen;
                });
              },
              onNavBeranda: () => _scrollToSection(_berandaKey),
              onNavFitur: () => _scrollToSection(_fiturKey),
              onNavStatistik: () => _scrollToSection(_statistikKey),
              onNavTim: () => _scrollToSection(_timKey),
              onNavKontak: () => _scrollToSection(_kontakKey),
            ),
          ),

          // Mobile Drawer Overlay Menu
          if (isMobile && _mobileMenuOpen)
            Positioned(
              top: 72,
              left: 0,
              right: 0,
              child: _MobileNavDropdown(
                onNavBeranda: () => _scrollToSection(_berandaKey),
                onNavFitur: () => _scrollToSection(_fiturKey),
                onNavStatistik: () => _scrollToSection(_statistikKey),
                onNavTim: () => _scrollToSection(_timKey),
                onNavKontak: () => _scrollToSection(_kontakKey),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// NAVBAR WIDGETS
// =============================================================================

class _StickyNavbar extends StatelessWidget {
  final bool isScrolled;
  final bool isMobile;
  final bool isMenuOpen;
  final VoidCallback onToggleMenu;
  final VoidCallback onNavBeranda;
  final VoidCallback onNavFitur;
  final VoidCallback onNavStatistik;
  final VoidCallback onNavTim;
  final VoidCallback onNavKontak;

  const _StickyNavbar({
    required this.isScrolled,
    required this.isMobile,
    required this.isMenuOpen,
    required this.onToggleMenu,
    required this.onNavBeranda,
    required this.onNavFitur,
    required this.onNavStatistik,
    required this.onNavTim,
    required this.onNavKontak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isScrolled
            ? Colors.white.withValues(alpha: 0.96)
            : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isScrolled ? AppColors.borderLight : Colors.transparent,
            width: 1,
          ),
        ),
        boxShadow: isScrolled
            ? [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  offset: const Offset(0, 4),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Brand Logo (Left)
              _BrandLogo(onTap: onNavBeranda),

              // Desktop Navigation Links (Right)
              if (!isMobile)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _NavLink(label: 'Beranda', onTap: onNavBeranda),
                    const SizedBox(width: 28),
                    _NavLink(label: 'Fitur', onTap: onNavFitur),
                    const SizedBox(width: 28),
                    _NavLink(label: 'Statistik', onTap: onNavStatistik),
                    const SizedBox(width: 28),
                    _NavLink(label: 'Tim & Program', onTap: onNavTim),
                    const SizedBox(width: 28),
                    _NavLink(label: 'Kontak', onTap: onNavKontak),
                  ],
                )
              else
                // Mobile Hamburger Toggle
                IconButton(
                  onPressed: onToggleMenu,
                  icon: Icon(
                    isMenuOpen ? Icons.close_rounded : Icons.menu_rounded,
                    color: AppColors.textPrimary,
                    size: 26,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  final VoidCallback onTap;

  const _BrandLogo({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset(
              'assets/logo.png',
              width: 38,
              height: 38,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'AGRI-MOTION',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _NavLink({
    required this.label,
    required this.onTap,
  });

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _isHovered
                ? AppColors.primaryEmerald
                : AppColors.textSecondary,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class _MobileNavDropdown extends StatelessWidget {
  final VoidCallback onNavBeranda;
  final VoidCallback onNavFitur;
  final VoidCallback onNavStatistik;
  final VoidCallback onNavTim;
  final VoidCallback onNavKontak;

  const _MobileNavDropdown({
    required this.onNavBeranda,
    required this.onNavFitur,
    required this.onNavStatistik,
    required this.onNavTim,
    required this.onNavKontak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: AppColors.borderLight),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _MobileNavItem(
            icon: Icons.home_outlined,
            title: 'Beranda',
            onTap: onNavBeranda,
          ),
          _MobileNavItem(
            icon: Icons.auto_awesome_outlined,
            title: 'Fitur Utama',
            onTap: onNavFitur,
          ),
          _MobileNavItem(
            icon: Icons.bar_chart_rounded,
            title: 'Statistik & Demplot',
            onTap: onNavStatistik,
          ),
          _MobileNavItem(
            icon: Icons.groups_outlined,
            title: 'Tim & Organisasi',
            onTap: onNavTim,
          ),
          _MobileNavItem(
            icon: Icons.mail_outline_rounded,
            title: 'Kontak',
            onTap: onNavKontak,
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.borderLight),
          const SizedBox(height: 12),
          const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Icon(icon, color: AppColors.primaryEmerald, size: 20),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

// =============================================================================
// HERO SECTION
// =============================================================================

class _HeroSection extends StatelessWidget {
  final VoidCallback onExplorePressed;
  final VoidCallback onLoginPressed;
  final Map<String, dynamic>? latestTelemetry;
  final bool isLoading;

  const _HeroSection({
    required this.onExplorePressed,
    required this.onLoginPressed,
    this.latestTelemetry,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;
    final bool isMobile = screenWidth < 768;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
      ),
      child: Stack(
        children: <Widget>[
          // Subtle background decorative circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),

          // Content Container
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 36,
                  vertical: isDesktop ? 80 : 54,
                ),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          // Left Column: Text & Actions
                          Expanded(
                            flex: 11,
                            child: _HeroTextContent(
                              onExplorePressed: onExplorePressed,
                              onLoginPressed: onLoginPressed,
                              isMobile: false,
                            ),
                          ),
                          const SizedBox(width: 48),
                          // Right Column: Live Telemetry Mockup Card
                          Expanded(
                            flex: 9,
                            child: _HeroDemplotSlider(
                              latestTelemetry: latestTelemetry,
                              isLoading: isLoading,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _HeroTextContent(
                            onExplorePressed: onExplorePressed,
                            onLoginPressed: onLoginPressed,
                            isMobile: isMobile,
                          ),
                          const SizedBox(height: 40),
                          _HeroDemplotSlider(
                            latestTelemetry: latestTelemetry,
                            isLoading: isLoading,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTextContent extends StatelessWidget {
  final VoidCallback onExplorePressed;
  final VoidCallback onLoginPressed;
  final bool isMobile;

  const _HeroTextContent({
    required this.onExplorePressed,
    required this.onLoginPressed,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Text(
            'PPKO BEM FMIPA UNUD 2026 • Desa Nyanglan, Klungkung',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 20),

        // Headline
        Text(
          'Pertanian Cerdas dengan Pemantauan dan Otomasi Presisi',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: isMobile ? 30 : 44,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 18),

        // Subheadline
        Text(
          'Platform monitoring tanah, iklim mikro, dan irigasi otomatis berbasis Internet of Things untuk demplot binaan di Desa Nyanglan, Klungkung.',
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: isMobile ? 15 : 17,
            fontWeight: FontWeight.w400,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),

        // CTA Action Buttons
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: <Widget>[
            ElevatedButton.icon(
              onPressed: onLoginPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryEmerald,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                shadowColor: Colors.black.withValues(alpha: 0.25),
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: Text(
                'Pelajari Program',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onExplorePressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1.5),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.arrow_downward_rounded, size: 18),
              label: Text(
                'Lihat Demplot',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // Trust indicators
        Row(
          children: <Widget>[
            _HeroFeaturePill(icon: Icons.wifi_tethering, label: 'Konektivitas IoT'),
            const SizedBox(width: 16),
            _HeroFeaturePill(icon: Icons.speed_rounded, label: 'Telemetri Real-time'),
            const SizedBox(width: 16),
            _HeroFeaturePill(icon: Icons.shield_outlined, label: 'Otomasi Andal'),
          ],
        ),
      ],
    );
  }
}

class _HeroFeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroFeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: const Color(0xFF86EFAC), size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HeroDemplotSlider extends StatefulWidget {
  final Map<String, dynamic>? latestTelemetry;
  final bool isLoading;

  const _HeroDemplotSlider({
    this.latestTelemetry,
    this.isLoading = false,
  });

  @override
  State<_HeroDemplotSlider> createState() => _HeroDemplotSliderState();
}

class _HeroDemplotSliderState extends State<_HeroDemplotSlider> {
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _demplots = [
    {
      'name': 'Demplot 1: Bunga Pacah',
      'emoji': '🌸',
      'commodity': 'Tanaman Hias & Upakara',
      'moisture': '65.2',
      'ph': '6.8',
      'temp': '27.8',
      'humidity': '76',
      'status': 'Optimal',
    },
    {
      'name': 'Demplot 2: Sawi Organik',
      'emoji': '🥬',
      'commodity': 'Sayuran Daun Presisi',
      'moisture': '68.4',
      'ph': '6.5',
      'temp': '26.5',
      'humidity': '78',
      'status': 'Optimal',
    },
    {
      'name': 'Demplot 3: Cabai Rawit',
      'emoji': '🌶️',
      'commodity': 'Hortikultura Unggulan',
      'moisture': '58.7',
      'ph': '6.7',
      'temp': '28.2',
      'humidity': '72',
      'status': 'Optimal',
    },
  ];

  void _next() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _demplots.length;
    });
  }

  void _prev() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + _demplots.length) % _demplots.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final demplot = _demplots[_currentIndex];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header with Demplot Title, Prev/Next Arrows and Online Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    Text(
                      demplot['emoji'] as String,
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            demplot['name'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            demplot['commodity'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Arrows & Indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                    onPressed: _prev,
                    tooltip: 'Demplot Sebelumnya',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.backgroundLight,
                      foregroundColor: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentIndex + 1}/3',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryEmerald,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onPressed: _next,
                    tooltip: 'Demplot Selanjutnya',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.backgroundLight,
                      foregroundColor: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Desa Nyanglan, Klungkung • Data Terkini',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.optimalGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ONLINE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryEmerald,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Animated Switcher for Smooth Demplot Transition
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(
              key: ValueKey<int>(_currentIndex),
              child: Column(
                children: [
                  // 2x2 Telemetry Metric Widgets
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _HeroMetricBox(
                          icon: Icons.water_drop_outlined,
                          iconColor: AppColors.secondary,
                          label: 'Kelembaban Tanah',
                          value: widget.isLoading ? '...' : '${widget.latestTelemetry?['soilMoisture'] ?? demplot['moisture']} %',
                          status: 'Optimal',
                          statusColor: AppColors.optimalGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _HeroMetricBox(
                          icon: Icons.science_outlined,
                          iconColor: AppColors.primaryEmerald,
                          label: 'pH Tanah',
                          value: widget.isLoading ? '...' : '${widget.latestTelemetry?['ph'] ?? demplot['ph']}',
                          status: 'Netral',
                          statusColor: AppColors.optimalGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _HeroMetricBox(
                          icon: Icons.thermostat_rounded,
                          iconColor: Colors.deepOrange,
                          label: 'Suhu Udara',
                          value: widget.isLoading ? '...' : '${widget.latestTelemetry?['temperature'] ?? demplot['temp']} °C',
                          status: 'Ideal',
                          statusColor: AppColors.optimalGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _HeroMetricBox(
                          icon: Icons.cloud_queue_rounded,
                          iconColor: Colors.indigo,
                          label: 'Kelembaban Udara',
                          value: widget.isLoading ? '...' : '${widget.latestTelemetry?['humidity'] ?? demplot['humidity']} %',
                          status: 'Optimal',
                          statusColor: AppColors.optimalGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.borderLight),
          const SizedBox(height: 10),

          // Irrigation Automation Status
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.power_settings_new_rounded,
                  color: AppColors.primaryEmerald,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Sistem Irigasi & Otomasi Presisi',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Aktuator Otomatis Terhubung',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.optimalGreen,
                size: 18,
              ),
            ],
          ),

          const SizedBox(height: 12),
          // Dots Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _demplots.length,
              (index) => GestureDetector(
                onTap: () => setState(() => _currentIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentIndex == index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? AppColors.primaryEmerald
                        : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetricBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String status;
  final Color statusColor;

  const _HeroMetricBox({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Icon(icon, color: iconColor, size: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FEATURES / KEUNGGULAN SECTION
// =============================================================================

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;
    final bool isTablet = screenWidth >= 640 && screenWidth < 1024;
    final bool isMobile = screenWidth < 640;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 36,
        vertical: 80,
      ),
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Section Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'KEUNGGULAN SISTEM',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.primaryEmerald,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Fitur Terintegrasi Pertanian Modern',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 26 : 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Text(
                  'Solusi menyeluruh dari sensor tanah, transmisi IoT berdaya rendah, hingga analitik data komprehensif untuk mendongkrak hasil panen demplot.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 56),

              // Responsive Cards Layout
              if (isDesktop)
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.sensors_rounded,
                        iconBgColor: Color(0xFFE8F5EE),
                        iconColor: AppColors.primaryEmerald,
                        tag: 'Real-Time',
                        title: 'Telemetri Real-time',
                        description:
                            'Monitor kelembaban tanah, pH, NPK, suhu & kelembaban udara secara langsung dengan transmisi data berkecepatan tinggi.',
                      ),
                    ),
                    SizedBox(width: 24),
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.water_drop_rounded,
                        iconBgColor: Color(0xFFE0F2FE),
                        iconColor: AppColors.secondary,
                        tag: 'Otomasi Presisi',
                        title: 'Irigasi & Penyemprotan Presisi',
                        description:
                            'Kontrol aktuator pompa pupuk, pestisida, dan air dari dashboard berbasis jadwal otomatis maupun pemicu kondisi sensor.',
                      ),
                    ),
                    SizedBox(width: 24),
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.notification_important_rounded,
                        iconBgColor: Color(0xFFFEF3C7),
                        iconColor: AppColors.warningAmber,
                        tag: 'Peringatan Dini',
                        title: 'Deteksi Dini Anomali',
                        description:
                            'Sistem peringatan otomatis saat parameter tanah melewati ambang batas toleransi tanaman untuk mencegah gagal panen sedini mungkin.',
                      ),
                    ),
                    SizedBox(width: 24),
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.insights_rounded,
                        iconBgColor: Color(0xFFEDE9FE),
                        iconColor: Color(0xFF7C3AED),
                        tag: 'Analisis & Riset',
                        title: 'Analitik & Laporan',
                        description:
                            'Visualisasi tren data historis dan ekspor laporan CSV/JSON lengkap untuk evaluasi berkala dan riset agronomi terstruktur.',
                      ),
                    ),
                  ],
                )
              else if (isTablet)
                const Column(
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: _FeatureCard(
                            icon: Icons.sensors_rounded,
                            iconBgColor: Color(0xFFE8F5EE),
                            iconColor: AppColors.primaryEmerald,
                            tag: 'Real-Time',
                            title: 'Telemetri Real-time',
                            description:
                                'Monitor kelembaban tanah, pH, NPK, suhu & kelembaban udara secara langsung dengan transmisi data berkecepatan tinggi.',
                          ),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: _FeatureCard(
                            icon: Icons.water_drop_rounded,
                            iconBgColor: Color(0xFFE0F2FE),
                            iconColor: AppColors.secondary,
                            tag: 'Otomasi Presisi',
                            title: 'Irigasi & Penyemprotan Presisi',
                            description:
                                'Kontrol aktuator pompa pupuk, pestisida, dan air dari dashboard berbasis jadwal otomatis maupun pemicu sensor.',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: _FeatureCard(
                            icon: Icons.notification_important_rounded,
                            iconBgColor: Color(0xFFFEF3C7),
                            iconColor: AppColors.warningAmber,
                            tag: 'Peringatan Dini',
                            title: 'Deteksi Dini Anomali',
                            description:
                                'Sistem peringatan otomatis saat parameter tanah melewati ambang batas toleransi tanaman untuk mencegah gagal panen sedini mungkin.',
                          ),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: _FeatureCard(
                            icon: Icons.insights_rounded,
                            iconBgColor: Color(0xFFEDE9FE),
                            iconColor: Color(0xFF7C3AED),
                            tag: 'Analisis & Riset',
                            title: 'Analitik & Laporan',
                            description:
                                'Visualisasi tren data historis dan ekspor laporan CSV/JSON lengkap untuk evaluasi berkala dan riset agronomi terstruktur.',
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                // Mobile stacked
                const Column(
                  children: <Widget>[
                    _FeatureCard(
                      icon: Icons.sensors_rounded,
                      iconBgColor: Color(0xFFE8F5EE),
                      iconColor: AppColors.primaryEmerald,
                      tag: 'Real-Time',
                      title: 'Telemetri Real-time',
                      description:
                          'Monitor kelembaban tanah, pH, NPK, suhu & kelembaban udara secara langsung dengan transmisi data berkecepatan tinggi.',
                    ),
                    SizedBox(height: 16),
                    _FeatureCard(
                      icon: Icons.water_drop_rounded,
                      iconBgColor: Color(0xFFE0F2FE),
                      iconColor: AppColors.secondary,
                      tag: 'Otomasi Presisi',
                      title: 'Irigasi & Penyemprotan Presisi',
                      description:
                          'Kontrol aktuator pompa pupuk, pestisida, dan air dari dashboard berbasis jadwal otomatis maupun pemicu sensor.',
                    ),
                    SizedBox(height: 16),
                    _FeatureCard(
                      icon: Icons.notification_important_rounded,
                      iconBgColor: Color(0xFFFEF3C7),
                      iconColor: AppColors.warningAmber,
                      tag: 'Peringatan Dini',
                      title: 'Deteksi Dini Anomali',
                      description:
                          'Sistem peringatan otomatis saat parameter tanah melewati ambang batas toleransi tanaman untuk mencegah gagal panen sedini mungkin.',
                    ),
                    SizedBox(height: 16),
                    _FeatureCard(
                      icon: Icons.insights_rounded,
                      iconBgColor: Color(0xFFEDE9FE),
                      iconColor: Color(0xFF7C3AED),
                      tag: 'Analisis & Riset',
                      title: 'Analitik & Laporan',
                      description:
                          'Visualisasi tren data historis dan ekspor laporan CSV/JSON lengkap untuk evaluasi berkala dan riset agronomi terstruktur.',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String tag;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.tag,
    required this.title,
    required this.description,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -6 : 0, 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? AppColors.primaryEmerald.withValues(alpha: 0.5)
                : AppColors.borderLight,
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? AppColors.primaryEmerald.withValues(alpha: 0.1)
                  : const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: _isHovered ? 24 : 12,
              offset: Offset(0, _isHovered ? 10 : 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 24),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    widget.tag,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.description,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// STATS & DEMPLOT SHOWCASE SECTION
// =============================================================================

class _StatsAndDemplotSection extends StatelessWidget {
  final int totalDataPoints;
  final int activeSensorNodes;
  final int activeDemplots;
  
  const _StatsAndDemplotSection({
    this.totalDataPoints = 189126,
    this.activeSensorNodes = 3,
    this.activeDemplots = 3,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;
    final bool isMobile = screenWidth < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 36,
        vertical: 80,
      ),
      color: AppColors.backgroundLight,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Section Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'STATISTIK & DEMPLOT BINAAN',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.primaryEmerald,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Dampak Nyata di Lapangan',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 26 : 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Text(
                  'Data implementasi perangkat sensor dan kaderisasi petani muda dalam program pendampingan di Desa Nyanglan, Klungkung.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // 3 Main Statistics Cards
              if (isDesktop)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _StatCard(
                        value: activeDemplots.toString(),
                        label: 'Demplot Aktif Binaan',
                        description:
                            'Komoditas unggulan: Bunga Pacah 🌸, Sawi 🥬, dan Cabai 🌶️',
                        icon: Icons.agriculture_rounded,
                        accentColor: AppColors.primaryEmerald,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _StatCard(
                        value: totalDataPoints > 0 ? '${(totalDataPoints / 1000).toStringAsFixed(1)}k+' : '...',
                        label: 'Total Transmisi Sensor',
                        description:
                            'Titik data tanah & mikroklimat terkirim dan teranalisis otomatis.',
                        icon: Icons.data_usage_rounded,
                        accentColor: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _StatCard(
                        value: activeSensorNodes > 0 ? activeSensorNodes.toString() : '...',
                        label: 'Sensor IoT Aktif',
                        description:
                            'Perangkat IoT mendeteksi kondisi demplot 24/7.',
                        icon: Icons.sensors_rounded,
                        accentColor: AppColors.optimalGreen,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: <Widget>[
                    _StatCard(
                      value: activeDemplots.toString(),
                      label: 'Demplot Aktif Binaan',
                      description:
                          'Komoditas unggulan: Bunga Pacah 🌸, Sawi 🥬, dan Cabai 🌶️',
                      icon: Icons.agriculture_rounded,
                      accentColor: AppColors.primaryEmerald,
                    ),
                    const SizedBox(height: 16),
                    _StatCard(
                      value: totalDataPoints > 0 ? '${(totalDataPoints / 1000).toStringAsFixed(1)}k+' : '...',
                      label: 'Total Transmisi Sensor',
                      description:
                          'Titik data tanah & mikroklimat terkirim dan teranalisis otomatis.',
                      icon: Icons.data_usage_rounded,
                      accentColor: AppColors.secondary,
                    ),
                    const SizedBox(height: 16),
                    _StatCard(
                      value: activeSensorNodes > 0 ? activeSensorNodes.toString() : '...',
                      label: 'Sensor IoT Aktif',
                      description:
                          'Perangkat IoT mendeteksi kondisi demplot 24/7.',
                      icon: Icons.sensors_rounded,
                      accentColor: AppColors.optimalGreen,
                    ),
                  ],
                ),

              const SizedBox(height: 64),

              // Demplot Showcase Subheader
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Profil 3 Lahan Demplot Binaan',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Setiap demplot dilengkapi sensor IoT presisi yang memantau kondisi tanah secara mandiri.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3 Demplot Cards
              if (isDesktop)
                const Row(
                  children: <Widget>[
                    Expanded(
                      child: _DemplotCard(
                        demplotNumber: 'Demplot 1',
                        commodity: 'Bunga Pacah',
                        emoji: '🌸',
                        nodeCode: 'Demplot Bunga Pacah',
                        targetMoisture: '65% - 80%',
                        targetPh: '6.0 - 7.0',
                        focusDesc:
                            'Optimasi kelembaban tanah untuk pembungaan lebat dan konsistensi warna kelopak.',
                        status: 'Aktif & Beroperasi',
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: _DemplotCard(
                        demplotNumber: 'Demplot 2',
                        commodity: 'Sawi Hijau',
                        emoji: '🥬',
                        nodeCode: 'Demplot Sawi',
                        targetMoisture: '70% - 85%',
                        targetPh: '6.2 - 6.8',
                        focusDesc:
                            'Irigasi presisi dan pemantauan NPK mikro untuk pertumbuhan vegetatif daun yang cepat.',
                        status: 'Aktif & Beroperasi',
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: _DemplotCard(
                        demplotNumber: 'Demplot 3',
                        commodity: 'Cabai Rawit',
                        emoji: '🌶️',
                        nodeCode: 'Demplot Cabai',
                        targetMoisture: '60% - 75%',
                        targetPh: '6.0 - 6.5',
                        focusDesc:
                            'Pengendalian drainase dan deteksi pH tanah guna mencegah penyakit busuk akar & antraknosa.',
                        status: 'Aktif & Beroperasi',
                      ),
                    ),
                  ],
                )
              else
                const Column(
                  children: <Widget>[
                    _DemplotCard(
                      demplotNumber: 'Demplot 1',
                      commodity: 'Bunga Pacah',
                      emoji: '🌸',
                      nodeCode: 'Demplot Bunga Pacah',
                      targetMoisture: '65% - 80%',
                      targetPh: '6.0 - 7.0',
                      focusDesc:
                          'Optimasi kelembaban tanah untuk pembungaan lebat dan konsistensi warna kelopak.',
                      status: 'Aktif & Beroperasi',
                    ),
                    SizedBox(height: 16),
                    _DemplotCard(
                      demplotNumber: 'Demplot 2',
                      commodity: 'Sawi Hijau',
                      emoji: '🥬',
                      nodeCode: 'Demplot Sawi',
                      targetMoisture: '70% - 85%',
                      targetPh: '6.2 - 6.8',
                      focusDesc:
                          'Irigasi presisi dan pemantauan NPK mikro untuk pertumbuhan vegetatif daun yang cepat.',
                      status: 'Aktif & Beroperasi',
                    ),
                    SizedBox(height: 16),
                    _DemplotCard(
                      demplotNumber: 'Demplot 3',
                      commodity: 'Cabai Rawit',
                      emoji: '🌶️',
                      nodeCode: 'Demplot Cabai',
                      targetMoisture: '60% - 75%',
                      targetPh: '6.0 - 6.5',
                      focusDesc:
                          'Pengendalian drainase dan deteksi pH tanah guna mencegah penyakit busuk akar & antraknosa.',
                      status: 'Aktif & Beroperasi',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final Color accentColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const Icon(
                Icons.trending_up_rounded,
                color: AppColors.optimalGreen,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemplotCard extends StatelessWidget {
  final String demplotNumber;
  final String commodity;
  final String emoji;
  final String nodeCode;
  final String targetMoisture;
  final String targetPh;
  final String focusDesc;
  final String status;

  const _DemplotCard({
    required this.demplotNumber,
    required this.commodity,
    required this.emoji,
    required this.nodeCode,
    required this.targetMoisture,
    required this.targetPh,
    required this.focusDesc,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: Emoji & Demplot Name
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        demplotNumber,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryEmerald,
                        ),
                      ),
                      Text(
                        commodity,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ONLINE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryEmerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.borderLight),
          const SizedBox(height: 12),

          // Node information
          Row(
            children: <Widget>[
              const Icon(
                Icons.router_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Status: Aktif Real-Time',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Target parameters
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Target Kelembaban',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        targetMoisture,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Target pH Tanah',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        targetPh,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.optimalGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            focusDesc,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TEAM & ORGANIZATION SECTION (PPKO BEM FMIPA UNUD)
// =============================================================================

class _TeamSection extends StatelessWidget {
  const _TeamSection();

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;
    final bool isMobile = screenWidth < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 36,
        vertical: 80,
      ),
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Section Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'TIM & ORGANISASI PENGEMBANG',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.primaryEmerald,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Inovasi Mahasiswa untuk Kedaulatan Tani',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 26 : 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Text(
                  'Program Penguatan Kapasitas Organisasi Kemahasiswaan (PPKO) BEM FMIPA Universitas Udayana di Desa Dampingan Nyanglan, Klungkung.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Program Details Main Container
              Container(
                padding: EdgeInsets.all(isMobile ? 24 : 40),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF0FDF4), Color(0xFFF8FAFC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: isDesktop
                    ? const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Left column: Organization & Story
                          Expanded(
                            flex: 11,
                            child: _OrgInfoCard(),
                          ),
                          SizedBox(width: 40),
                          // Right column: 4 Program Pillars
                          Expanded(
                            flex: 9,
                            child: _ProgramPillarsCard(),
                          ),
                        ],
                      )
                    : const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _OrgInfoCard(),
                          SizedBox(height: 32),
                          Divider(color: AppColors.borderLight),
                          SizedBox(height: 24),
                          _ProgramPillarsCard(),
                        ],
                      ),
              ),

              const SizedBox(height: 36),

              // Institution Affiliation Badges
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: const <Widget>[
                  _AffiliationBadge(
                    icon: Icons.school_rounded,
                    label: 'Universitas Udayana',
                  ),
                  _AffiliationBadge(
                    icon: Icons.account_balance_rounded,
                    label: 'BEM FMIPA UNUD',
                  ),
                  _AffiliationBadge(
                    icon: Icons.verified_rounded,
                    label: 'PPKO Kemendikbudristek',
                  ),
                  _AffiliationBadge(
                    icon: Icons.location_on_rounded,
                    label: 'Desa Nyanglan, Klungkung',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrgInfoCard extends StatelessWidget {
  const _OrgInfoCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryEmerald,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'PPKO BEM FMIPA Universitas Udayana',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Program Penguatan Kapasitas Ormawa',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryEmerald,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.place_rounded,
                color: AppColors.dangerRose,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Desa Dampingan: Desa Nyanglan, Kecamatan Banjarangkan, Kabupaten Klungkung',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'AGRI-MOTION merupakan wujud dedikasi mahasiswa FMIPA Universitas Udayana dalam mentransformasi sektor pertanian tradisional menjadi sistem berbasis data presisi. Melalui instalasi modul IoT, pelatihan kader tani muda, dan sistem kendali aktuator otomatis, program ini bertujuan meningkatkan efisiensi penggunaan air dan pupuk serta meningkatkan ketahanan pangan masyarakat pedesaan.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _ProgramPillarsCard extends StatelessWidget {
  const _ProgramPillarsCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Pilar Fokus Program',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        const _PillarItem(
          number: '01',
          title: 'Digitalisasi Lahan Pertanian',
          subtitle:
              'Instalasi perangkat sensor tanah dan transmisi nirkabel real-time.',
        ),
        const SizedBox(height: 12),
        const _PillarItem(
          number: '02',
          title: 'Konservasi Air & Nutrisi Pupuk',
          subtitle:
              'Penyiraman dan pemupukan presisi berbasis data ambang batas kebutuhan tanaman.',
        ),
        const SizedBox(height: 12),
        const _PillarItem(
          number: '03',
          title: 'Kaderisasi Petani Muda',
          subtitle:
              'Pelatihan teknologi komputasi awan dan pemeliharaan perangkat kepada generasi muda desa.',
        ),
        const SizedBox(height: 12),
        const _PillarItem(
          number: '04',
          title: 'Keberlanjutan & Pendampingan',
          subtitle:
              'Pendampingan berkelanjutan bersama kelompok tani desa binaan hingga mandiri.',
        ),
      ],
    );
  }
}

class _PillarItem extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const _PillarItem({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              number,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryEmerald,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AffiliationBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AffiliationBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AppColors.primaryEmerald, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}



// =============================================================================
// FOOTER
// =============================================================================

class _Footer extends StatelessWidget {
  final VoidCallback onNavHome;
  final VoidCallback onNavFeatures;
  final VoidCallback onNavStats;
  final VoidCallback onNavTeam;
  final VoidCallback onNavAdmin;

  const _Footer({
    required this.onNavHome,
    required this.onNavFeatures,
    required this.onNavStats,
    required this.onNavTeam,
    required this.onNavAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;
    final bool isMobile = screenWidth < 768;

    return Container(
      color: const Color(0xFF0A1912), // Deep forest dark footer
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 36,
        vertical: 60,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: <Widget>[
              // Top Footer Grid
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Col 1: Brand & Bio
                    Expanded(
                      flex: 6,
                      child: _FooterBrandColumn(onHomeTap: onNavHome),
                    ),
                    const SizedBox(width: 64),
                    // Col 2: Contact info
                    const Expanded(
                      flex: 5,
                      child: _FooterContactColumn(),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _FooterBrandColumn(onHomeTap: onNavHome),
                    const SizedBox(height: 32),
                    const Divider(color: Color(0xFF1E3A2B)),
                    const SizedBox(height: 24),
                    const _FooterContactColumn(),
                  ],
                ),

              const SizedBox(height: 48),
              const Divider(color: Color(0xFF1E3A2B)),
              const SizedBox(height: 28),

              // Bottom Copyright Bar
              Text(
                '© 2026 AGRI-MOTION - PPKO BEM FMIPA Universitas Udayana. Seluruh Hak Cipta Dilindungi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterBrandColumn extends StatelessWidget {
  final VoidCallback onHomeTap;

  const _FooterBrandColumn({required this.onHomeTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: onHomeTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.asset(
                'assets/logo.png',
                width: 38,
                height: 38,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AGRI-MOTION',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Platform Smart Agriculture berbasis Internet of Things (IoT) untuk pemantauan parameter tanah, iklim mikro, dan irigasi otomatis guna memajukan pertanian pedesaan berkelanjutan.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF94A3B8),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF132A1F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E3A2B)),
          ),
          child: Text(
            'PPKO BEM FMIPA UNUD 2026',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFE2E8F0),
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterContactColumn extends StatelessWidget {
  const _FooterContactColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Kontak & Lokasi',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const _ContactRow(
          icon: Icons.mail_outline_rounded,
          text: 'ppkormawabemfmipaunud2026@gmail.com',
        ),
        const SizedBox(height: 12),
        const _ContactRow(
          icon: Icons.phone_android_rounded,
          text: '+62 851 5609 3412 (WhatsApp)',
        ),
        const SizedBox(height: 12),
        const _ContactRow(
          icon: Icons.location_on_outlined,
          text: 'Desa Nyanglan, Kecamatan Banjarangkan, Kabupaten Klungkung',
        ),
        const SizedBox(height: 12),
        const _ContactRow(
          icon: Icons.account_balance_outlined,
          text: 'Gedung FH Bawah Kampus FMIPA Bukit Jimbaran Unud, Bali',
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContactRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: AppColors.leafGreen, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
