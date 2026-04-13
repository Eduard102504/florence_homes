// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFD4C4A8), // Light warm brown
              const Color(0xFFC4A882), // Medium warm brown
              const Color(0xFFB8A99A), // Soft brown
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo Container
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0.5, end: 1.0),
                builder: (context, double scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFF8F0),
                        Color(0xFFF5F0E8),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.home_work,
                    size: 65,
                    color: Color(0xFFD4C4A8),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Title with fade-in animation
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 600),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                builder: (context, double opacity, child) {
                  return Opacity(
                    opacity: opacity,
                    child: child,
                  );
                },
                child: const Text(
                  'Florence Homes',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFF8F0),
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black26,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle with slide-in animation
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 600),
                tween: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero),
                builder: (context, Offset offset, child) {
                  return Transform.translate(
                    offset: offset,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F0).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'Village Gate System',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFFFF8F0),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 60),

              // Loading indicator with custom styling
              const Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFF8F0)),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFFF8F0),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Decorative dots at bottom
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDot(),
                  const SizedBox(width: 8),
                  _buildDot(),
                  const SizedBox(width: 8),
                  _buildDot(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot() {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0.5, end: 1.0),
      builder: (context, double scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F0).withOpacity(0.6),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      },
    );
  }
}