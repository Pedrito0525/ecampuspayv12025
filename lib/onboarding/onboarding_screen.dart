import 'package:flutter/material.dart';
import '../login_page.dart';
import '../utils/onboarding_utils.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Color evsuRed = const Color(0xFFB01212);

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to eCampusPay',
      subtitle: 'Your Digital Campus Payment Solution',
      description:
          'Experience the future of campus payments with EVSU\'s innovative tap-to-pay system. No more cash, no more hassle - just tap and go!',
      icon: Icons.school_outlined,
      backgroundColor: Color(0xFFB01212),
      textColor: Colors.white,
      image: 'assets/ecampuspaylogo3v.png',
      iconSize: 80.0,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB01212), Color(0xFF8B0000)],
      ),
    ),
    OnboardingPage(
      title: 'Tap to Pay',
      subtitle: 'School ID RFID Card Technology',
      description:
          'Simply tap your EVSU School ID RFID card to make instant payments across campus. Fast, secure, and contactless - perfect for busy student life.',
      icon: Icons.credit_card_outlined,
      backgroundColor: Color(0xFF2E7D32),
      textColor: Colors.white,
      features: [
        'School ID Card',
        'Instant Payments',
        'No Cash Needed',
        'Contactless Security',
      ],
      iconSize: 80.0,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
      ),
    ),
    OnboardingPage(
      title: 'Easy Top-Up',
      subtitle: 'Recharge at EVSU Admin or Services',
      description:
          'Add funds to your account at EVSU admin offices or authorized service centers. Secure and convenient top-up options available only on campus.',
      icon: Icons.account_balance_wallet_outlined,
      backgroundColor: Color(0xFF1976D2),
      textColor: Colors.white,
      features: [
        'EVSU Admin Offices',
        'Campus Service Centers',
        'Instant Balance Update',
        'Secure Campus Transactions',
      ],
      iconSize: 80.0,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
      ),
    ),
    OnboardingPage(
      title: 'Campus Vendors',
      subtitle: 'Pay at All EVSU Services',
      description:
          'Use your eCampusPay at campus cafeterias, bookstores, printing services, and all authorized campus vendors. One card, endless possibilities!',
      icon: Icons.storefront_outlined,
      backgroundColor: Color(0xFF7B1FA2),
      textColor: Colors.white,
      features: [
        'Campus Cafeteria',
        'Bookstore',
        'Printing Services',
        'All Vendors',
      ],
      iconSize: 80.0,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
      ),
    ),
    OnboardingPage(
      title: 'Service Units',
      subtitle: 'Pay for EVSU Campus Services',
      description:
          'Settle payments for various EVSU campus services including library fees, laboratory charges, and other administrative services seamlessly.',
      icon: Icons.business_center_outlined,
      backgroundColor: Color(0xFFE65100),
      textColor: Colors.white,
      features: [
        'EVSU Library Fees',
        'Laboratory Charges',
        'Administrative Services',
        'Quick Campus Processing',
      ],
      iconSize: 80.0,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE65100), Color(0xFFBF360C)],
      ),
    ),
    OnboardingPage(
      title: 'Student Organizations',
      subtitle: 'Support Campus Life',
      description:
          'Contribute to student organizations, events, and activities through easy payments. Be part of the vibrant EVSU community!',
      icon: Icons.groups_outlined,
      backgroundColor: Color(0xFFD32F2F),
      textColor: Colors.white,
      features: [
        'Event Tickets',
        'Club Dues',
        'Activities',
        'Community Support',
      ],
      iconSize: 80.0,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
      ),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    try {
      print('DEBUG: Starting onboarding completion...');

      // Mark onboarding as completed
      await OnboardingUtils.markOnboardingCompleted();
      print('DEBUG: Onboarding marked as completed');

      // Verify it was saved
      final verified = await OnboardingUtils.isOnboardingCompleted();
      print('DEBUG: Onboarding completion verified: $verified');

      if (!mounted) return;

      // Navigate to login page
      print('DEBUG: Navigating to LoginPage from OnboardingScreen');
      await Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    } catch (e) {
      print('ERROR completing onboarding: $e');
      // Still navigate to login even if save fails
      if (mounted) {
        await Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;
    final isPhone = screenWidth < 400;

    // Responsive padding calculations
    final horizontalPadding = isLargeTablet ? 48.0 : (isTablet ? 32.0 : 20.0);
    final verticalPadding = isLargeTablet ? 32.0 : (isTablet ? 24.0 : 16.0);
    final buttonPadding = isTablet ? 24.0 : 16.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with navigation
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button (only show if not on first page)
                  if (_currentPage > 0)
                    IconButton(
                      onPressed: _previousPage,
                      icon: Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Colors.white,
                        size: isTablet ? 28 : 24,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  else
                    SizedBox(width: isTablet ? 56 : 48),

                  // Skip button
                  TextButton.icon(
                    onPressed: _skipOnboarding,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 20 : 16,
                        vertical: isTablet ? 12 : 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: Icon(
                      Icons.skip_next_rounded,
                      size: isTablet ? 20 : 18,
                    ),
                    label: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page indicator with improved design
            Container(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width:
                        _currentPage == index
                            ? (isTablet ? 32 : 28)
                            : (isTablet ? 12 : 10),
                    height: isTablet ? 8 : 6,
                    decoration: BoxDecoration(
                      color:
                          _currentPage == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(isTablet ? 6 : 4),
                      boxShadow:
                          _currentPage == index
                              ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: isTablet ? 16 : 12),

            // Page content with improved responsiveness
            Expanded(
              child: GestureDetector(
                // Prevent tap navigation - only allow swipe gestures
                onTap: () {
                  // Absorb taps to prevent accidental navigation
                },
                child: PageView.builder(
                  controller: _pageController,
                  physics:
                      const PageScrollPhysics(), // Only allow swipe gestures
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      // Prevent taps on page content from navigating
                      onTap: () {
                        // Absorb taps to prevent navigation
                      },
                      child: _buildOnboardingPage(
                        _pages[index],
                        isTablet,
                        isLargeTablet,
                        isPhone,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Navigation buttons with improved design
            Container(
              padding: EdgeInsets.all(buttonPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous button
                  if (_currentPage > 0)
                    OutlinedButton.icon(
                      onPressed: _previousPage,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white, width: 2),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 28 : 24,
                          vertical: isTablet ? 16 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        backgroundColor: Colors.white.withOpacity(0.1),
                      ),
                      icon: Icon(
                        Icons.arrow_back_ios_rounded,
                        size: isTablet ? 18 : 16,
                      ),
                      label: Text(
                        'Previous',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    SizedBox(width: isTablet ? 140 : 120),

                  // Next/Get Started button
                  ElevatedButton.icon(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _pages[_currentPage].backgroundColor,
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 32 : 28,
                        vertical: isTablet ? 16 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                      shadowColor: Colors.black.withOpacity(0.3),
                    ),
                    icon: Icon(
                      _currentPage == _pages.length - 1
                          ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_ios_rounded,
                      size: isTablet ? 18 : 16,
                    ),
                    label: Text(
                      _currentPage == _pages.length - 1
                          ? 'Get Started'
                          : 'Next',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(
    OnboardingPage page,
    bool isTablet,
    bool isLargeTablet,
    bool isPhone,
  ) {
    // Responsive sizing calculations
    final iconSize =
        page.iconSize ?? (isLargeTablet ? 100.0 : (isTablet ? 80.0 : 70.0));
    final containerSize = isLargeTablet ? 160.0 : (isTablet ? 140.0 : 120.0);
    final titleFontSize =
        isLargeTablet ? 36.0 : (isTablet ? 32.0 : (isPhone ? 24.0 : 28.0));
    final subtitleFontSize =
        isLargeTablet ? 24.0 : (isTablet ? 20.0 : (isPhone ? 16.0 : 18.0));
    final descriptionFontSize =
        isLargeTablet ? 18.0 : (isTablet ? 16.0 : (isPhone ? 13.0 : 14.0));
    final featureFontSize =
        isLargeTablet ? 18.0 : (isTablet ? 16.0 : (isPhone ? 13.0 : 14.0));

    final horizontalPadding = isLargeTablet ? 48.0 : (isTablet ? 32.0 : 20.0);
    final verticalPadding = isLargeTablet ? 24.0 : (isTablet ? 16.0 : 12.0);

    return Container(
      decoration: BoxDecoration(
        gradient:
            page.gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                page.backgroundColor,
                page.backgroundColor.withOpacity(0.8),
              ],
            ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo/Icon with modern design
            Container(
              width: containerSize,
              height: containerSize,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child:
                  page.image != null
                      ? ClipOval(
                        child: Image.asset(
                          page.image!,
                          fit: BoxFit.cover,
                          width: containerSize,
                          height: containerSize,
                        ),
                      )
                      : Icon(page.icon, size: iconSize, color: page.textColor),
            ),

            SizedBox(height: isTablet ? 24 : 16),

            // Title with improved typography
            Text(
              page.title,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w800,
                color: page.textColor,
                letterSpacing: 0.5,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: isTablet ? 12 : 8),

            // Subtitle with better styling
            Text(
              page.subtitle,
              style: TextStyle(
                fontSize: subtitleFontSize,
                fontWeight: FontWeight.w600,
                color: page.textColor.withOpacity(0.9),
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: isTablet ? 16 : 12),

            // Description with improved readability
            Container(
              constraints: BoxConstraints(
                maxWidth: isLargeTablet ? 600 : (isTablet ? 500 : 350),
              ),
              child: Text(
                page.description,
                style: TextStyle(
                  fontSize: descriptionFontSize,
                  color: page.textColor.withOpacity(0.85),
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Features list with modern design
            if (page.features != null && page.features!.isNotEmpty) ...[
              SizedBox(height: isTablet ? 20 : 16),
              Container(
                constraints: BoxConstraints(
                  maxWidth: isLargeTablet ? 600 : (isTablet ? 500 : 350),
                ),
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children:
                      page.features!
                          .map(
                            (feature) => Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: isTablet ? 6 : 4,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: isTablet ? 24 : 20,
                                    height: isTablet ? 24 : 20,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      color: page.textColor,
                                      size: isTablet ? 16 : 14,
                                    ),
                                  ),
                                  SizedBox(width: isTablet ? 12 : 10),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: TextStyle(
                                        fontSize: featureFontSize,
                                        color: page.textColor,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ],

            SizedBox(height: isTablet ? 16 : 12),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final String? image;
  final List<String>? features;
  final double? iconSize;
  final LinearGradient? gradient;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    this.image,
    this.features,
    this.iconSize,
    this.gradient,
  });
}
