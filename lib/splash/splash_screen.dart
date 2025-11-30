import 'package:flutter/material.dart';
import '../onboarding/onboarding_screen.dart';
import '../login_page.dart';
import '../services/session_service.dart';
import '../utils/onboarding_utils.dart';

const bool _enableOnboarding = false;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    // Start animation and navigation
    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    try {
      // Start the animation
      _animationController.forward();

      // Wait for animation to complete and add some delay
      await Future.delayed(const Duration(milliseconds: 3000));

      if (!mounted) return;

      // Always clear any existing session on app startup
      // This ensures users always start fresh after app restart
      if (SessionService.isLoggedIn) {
        print('DEBUG: Found existing session on splash, clearing it');
        await SessionService.clearSessionOnAppClose();
      }

      // Check if onboarding has been completed
      final onboardingCompleted = await OnboardingUtils.isOnboardingCompleted();
      print('DEBUG: Onboarding completed status: $onboardingCompleted');

      if (!mounted) return;

      if (!_enableOnboarding) {
        if (!onboardingCompleted) {
          print(
            'DEBUG: Onboarding disabled - marking as completed automatically',
          );
          await OnboardingUtils.markOnboardingCompleted();
        }

        print('DEBUG: Onboarding disabled - navigating directly to LoginPage');
        await Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
        return;
      }

      // Navigate based on onboarding status
      if (onboardingCompleted) {
        print('DEBUG: Onboarding already completed, navigating to LoginPage');
        await Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
      } else {
        print(
          'DEBUG: Onboarding NOT completed, navigating to OnboardingScreen',
        );
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    } catch (e) {
      print('ERROR in splash sequence: $e');
      // Fallback to onboarding screen on error
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFB01212), // EVSU Red
              Color(0xFF7F1D1D), // Darker red
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Main Logo
                      Container(
                        width: isTablet ? 200 : 150,
                        height: isTablet ? 200 : 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/ecampuspaylogo3v.png',
                            fit: BoxFit.cover,
                            width: isTablet ? 200 : 150,
                            height: isTablet ? 200 : 150,
                          ),
                        ),
                      ),

                      SizedBox(height: isTablet ? 40 : 30),

                      // App Name
                      Text(
                        'eCampusPay',
                        style: TextStyle(
                          fontSize: isTablet ? 48 : 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),

                      SizedBox(height: isTablet ? 16 : 12),

                      // Tagline
                      Text(
                        'EVSU Digital Payment System',
                        style: TextStyle(
                          fontSize: isTablet ? 20 : 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 1,
                        ),
                      ),

                      SizedBox(height: isTablet ? 40 : 30),

                      // Loading indicator
                      SizedBox(
                        width: isTablet ? 40 : 30,
                        height: isTablet ? 40 : 30,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.8),
                          ),
                          strokeWidth: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
