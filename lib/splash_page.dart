import 'dart:async';
import 'package:flutter/material.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const Color evsuRed = Color(0xFFB01212);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double stripeWidth = size.width * 0.9;
    final double stripeThickness = 12;
    final double stripeGap = 14;
    const double angle = -0.6; // slanting angle in radians (~-34 degrees)

    return Scaffold(
      backgroundColor: evsuRed,
      body: Stack(
        children: [
          // Top-left slanted triple stripes
          Positioned(
            top: -size.width * 0.2,
            left: -size.width * 0.2,
            child: Transform.rotate(
              angle: angle,
              child: _StripeGroup(
                width: stripeWidth,
                thickness: stripeThickness,
                gap: stripeGap,
                color: Colors.white,
              ),
            ),
          ),

          // Bottom-right slanted triple stripes
          Positioned(
            bottom: -size.width * 0.2,
            right: -size.width * 0.2,
            child: Transform.rotate(
              angle: angle,
              child: _StripeGroup(
                width: stripeWidth,
                thickness: stripeThickness,
                gap: stripeGap,
                color: Colors.white,
              ),
            ),
          ),

          // Center logo (tinted to white)
          Center(
            child: Image.asset(
              'assets/letter_e.png',
              width: size.width * 0.34,
              fit: BoxFit.contain,
              color: Colors.white,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
        ],
      ),
    );
  }
}

class _StripeGroup extends StatelessWidget {
  const _StripeGroup({
    required this.width,
    required this.thickness,
    required this.gap,
    required this.color,
  });

  final double width;
  final double thickness;
  final double gap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stripe(),
        SizedBox(height: gap),
        _stripe(),
        SizedBox(height: gap),
        _stripe(),
      ],
    );
  }

  Widget _stripe() {
    return Container(width: width, height: thickness, color: color);
  }
}
