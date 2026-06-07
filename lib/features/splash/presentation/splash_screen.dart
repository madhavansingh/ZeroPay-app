import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/global_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  double _loadingProgress = 0.0;
  String _statusText = 'Booting ZeroPay Engine...';
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();

    // Setup premium logo animations
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.1).chain(CurveTween(curve: Curves.easeOutBack)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
    ]).animate(_controller);

    _rotationAnimation = Tween<double>(begin: -0.2, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    // Dynamic loading progress simulator
    const steps = [
      'Booting ZeroPay Engine...',
      'Initializing Cardano ledger node...',
      'Syncing trustless escrow network...',
      'Loading ZeroPay AI Assistant...',
      'Verifying device secure enclave...',
      'Session recovered. Welcome back.',
    ];

    int currentStepIndex = 0;
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) return;
      setState(() {
        _loadingProgress += 0.18;
        if (_loadingProgress >= 1.0) {
          _loadingProgress = 1.0;
          _loadingTimer?.cancel();
          _proceedToNextScreen();
        } else {
          int stepIdx = (_loadingProgress * steps.length).floor().clamp(0, steps.length - 1);
          if (stepIdx != currentStepIndex) {
            currentStepIndex = stepIdx;
            _statusText = steps[currentStepIndex];
          }
        }
      });
    });
  }

  void _proceedToNextScreen() {
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated && authState.user != null) {
      final target = authState.currentRole == 'merchant' ? '/merchant/home' : '/customer/home';
      context.go(target);
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _loadingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Radial Glowing Blur blob 1
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ),
          // Radial Glowing Blur blob 2
          Positioned(
            bottom: -150,
            right: -150,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.12),
              ),
            ),
          ),
          
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated 3D geometric Logo container
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: RotationTransition(
                    turns: _rotationAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            offset: const Offset(0, 16),
                            blurRadius: 32,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Inset highlights
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 2.0,
                                ),
                              ),
                            ),
                          ),
                          // Currency exchange icon
                          const Center(
                            child: Icon(
                              Icons.currency_exchange,
                              color: Colors.white,
                              size: 56,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // App Title & Tagline with fade-in transition
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                  builder: (context, opacity, child) {
                    return Opacity(
                      opacity: opacity,
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      Text(
                        'ZeroPay',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                              color: AppColors.onBackground,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The Blockchain Commerce OS',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                              letterSpacing: 0.5,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Progress & Status bar at the bottom
          Align(
            alignment: Alignment.bottomCenter,
            key: const ValueKey('progress-area'),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 64.0, left: 40.0, right: 40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress loader track
                  Container(
                    height: 4,
                    width: 140,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _loadingProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Status update text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _statusText,
                      key: ValueKey<String>(_statusText),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
