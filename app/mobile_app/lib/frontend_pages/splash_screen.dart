import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'homepage.dart';
import 'web_homepage.dart';
import '../frontend_theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final CameraDescription? camera;

  const SplashScreen({super.key, this.camera});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _controller.forward();

    // Fix TalkBack announcing package name
    SemanticsService.announce("Netra", TextDirection.ltr);

    // Navigate after delay
    Future.delayed(const Duration(seconds: 3), () {
      _navigateToHome();
    });
  }

  void _navigateToHome() {
    if (!mounted) return;

    Widget nextScreen;
    if (kIsWeb) {
      nextScreen = const WebHomePage();
    } else {
      if (widget.camera != null) {
        nextScreen = HomePage(camera: widget.camera!);
      } else {
        // Fallback if camera not passed or not available on mobile
        // Ideally should handle this case, but for now assuming camera exists as per main.dart logic
        nextScreen = const Scaffold(body: Center(child: Text("Camera not initialized"))); 
      }
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight, // Soft off-white
      body: Center(
        child: Semantics(
          label: "Netra. AI based smart navigation and vision assistant.",
          excludeSemantics: true, // Prevents reading children (Text widgets)
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _opacityAnimation.value,
                      child: Container(
                        width: 140, // Slightly larger
                        height: 140,
                        decoration: BoxDecoration(
                          gradient: AppTheme.charcoalGradient, // Charcoal Gradient
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2), // Softer shadow
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 4),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Base "Vision" Icon
                            const Icon(
                              Icons.remove_red_eye_outlined,
                              size: 80,
                              color: Colors.white,
                            ),
                            // Nested "Navigation/Smart" Icon overlay
                            Positioned(
                              bottom: 30,
                              child: Icon(
                                Icons.bolt, // Symbolizes AI/Power/Speed
                                size: 40,
                                color: AppTheme.primaryBrand, // Crimson Accent
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 48),
              FadeTransition(
                opacity: _opacityAnimation,
                child: Column(
                  children: [
                    Text(
                      'Netra',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: AppTheme.textPrimary,
                            fontSize: 42,
                            fontWeight: FontWeight.w900, // Extra bold
                            letterSpacing: 4.0,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'AI based smart navigation and vision assistant',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500, // Lighter weight
                              height: 1.5,
                              letterSpacing: 0.5,
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
    );
  }
}
