import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/providers/global_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _selectedTrackIndex = 0; // 0: Customer, 1: Merchant, 2: Hybrid
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  final List<String> _tracks = ['As Buyer', 'As Seller', 'Unified Pro'];

  // Data slides for each onboarding track
  final List<List<OnboardingSlide>> _slides = [
    // Customer Track
    [
      OnboardingSlide(
        title: 'Trustless Escrow',
        description: 'Experience flawless payments with our enterprise-grade smart contract architecture.',
        icon: Icons.lock_open,
        color: AppColors.primary,
        stepText: 'Buyer Step 1',
      ),
      OnboardingSlide(
        title: 'Secure Payments',
        description: 'Pay directly from your wallet with cryptographically locked milestone transfers.',
        icon: Icons.security_outlined,
        color: AppColors.primary,
        stepText: 'Buyer Step 2',
      ),
      OnboardingSlide(
        title: 'AI Negotiation',
        description: 'Secure the best deals automatically. Our intelligent agents negotiate terms for you.',
        icon: Icons.auto_awesome_outlined,
        color: AppColors.secondary,
        stepText: 'Buyer Step 3',
      ),
      OnboardingSlide(
        title: 'Cardano Verification',
        description: 'All assets and milestones are cryptographically audited on the Cardano ledger.',
        icon: Icons.verified_user_outlined,
        color: AppColors.primary,
        stepText: 'Buyer Step 4',
      ),
      OnboardingSlide(
        title: 'Dispute Protection',
        description: 'Decentralized jury arbitration secures your funds in case of contract violations.',
        icon: Icons.gavel_outlined,
        color: AppColors.tertiary,
        stepText: 'Buyer Step 5',
      ),
    ],
    // Merchant Track
    [
      OnboardingSlide(
        title: 'Escrow Commerce',
        description: 'Scale secure transactions without chargebacks using pre-funded buyer locks.',
        icon: Icons.storefront_outlined,
        color: AppColors.secondary,
        stepText: 'Seller Step 1',
      ),
      OnboardingSlide(
        title: 'Revenue Management',
        description: 'Real-time cashflow analytics, milestone distributions, and secure smart ledger.',
        icon: Icons.analytics_outlined,
        color: AppColors.primary,
        stepText: 'Seller Step 2',
      ),
      OnboardingSlide(
        title: 'AI Business Insights',
        description: 'Predictive pricing, demand signals, and automated API licensing recommendations.',
        icon: Icons.insights_outlined,
        color: AppColors.secondary,
        stepText: 'Seller Step 3',
      ),
      OnboardingSlide(
        title: 'Reputation Growth',
        description: 'Build immutable on-chain credit and escrow dispute resolution ratings.',
        icon: Icons.insights_outlined,
        color: AppColors.tertiary,
        stepText: 'Seller Step 4',
      ),
      OnboardingSlide(
        title: 'Instant Settlements',
        description: 'Access instantly cleared milestone funds directly to your verified address.',
        icon: Icons.payments_outlined,
        color: AppColors.primary,
        stepText: 'Seller Step 5',
      ),
    ],
    // Hybrid Track
    [
      OnboardingSlide(
        title: 'Unified Account Model',
        description: 'A single digital identity for managing both purchases and store revenue.',
        icon: Icons.account_circle_outlined,
        color: AppColors.primary,
        stepText: 'Pro Config 1',
      ),
      OnboardingSlide(
        title: 'Workspace Switching',
        description: 'Switch contexts instantly between buyer and merchant views with one tap.',
        icon: Icons.swap_horiz_outlined,
        color: AppColors.secondary,
        stepText: 'Pro Config 2',
      ),
      OnboardingSlide(
        title: 'Cross-role Reputation',
        description: 'Accumulate trust scores from both buyer contract fidelity and merchant sales.',
        icon: Icons.timeline_outlined,
        color: AppColors.tertiary,
        stepText: 'Pro Config 3',
      ),
    ],
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTrackChanged(int index) {
    setState(() {
      _selectedTrackIndex = index;
      _currentPageIndex = 0;
    });
    // Jump or animate pageview to start
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSlides = _slides[_selectedTrackIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top branding
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.all_inclusive,
                    color: AppColors.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ZeroPay',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                ],
              ),
            ),

            // Tactile Sliding Segmented Tab Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                    color: AppColors.outlineVariant.withOpacity(0.4),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: List.generate(_tracks.length, (index) {
                    final isSelected = _selectedTrackIndex == index;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _onTrackChanged(index),
                        child: Container(
                          margin: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.surfaceContainerLowest : Colors.transparent,
                            borderRadius: BorderRadius.circular(20.0),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _tracks[index],
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Carousel Slide Container
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: activeSlides.length,
                  onPageChanged: (pageIndex) {
                    setState(() {
                      _currentPageIndex = pageIndex;
                    });
                  },
                  itemBuilder: (context, slideIndex) {
                    final slide = activeSlides[slideIndex];
                    return Padding(
                      key: ValueKey('${_selectedTrackIndex}_$slideIndex'),
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: BentoCard(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 3D-feeling Icon Bubble
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.surfaceContainerHigh.withOpacity(0.4),
                                border: Border.all(
                                  color: AppColors.outlineVariant.withOpacity(0.3),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  slide.icon,
                                  size: 56,
                                  color: slide.color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 36),

                            // Micro Step Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                              decoration: BoxDecoration(
                                color: slide.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 12,
                                    color: slide.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    slide.stepText,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: slide.color,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Slide Title
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                    color: AppColors.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 12),

                            // Slide Description
                            Text(
                              slide.description,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    height: 1.4,
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

            // Pagination Dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(activeSlides.length, (index) {
                  final isCurrent = _currentPageIndex == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    height: 8,
                    width: isCurrent ? 24 : 8,
                    decoration: BoxDecoration(
                      color: isCurrent ? AppColors.primary : AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 32.0),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      text: _currentPageIndex == activeSlides.length - 1 ? 'Get Started' : 'Continue',
                      onPressed: () async {
                        if (_currentPageIndex < activeSlides.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          // Complete onboarding and jump to auth screen
                          await ref.read(authProvider.notifier).completeOnboarding();
                          if (mounted) context.go('/auth');
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () async {
                        // Complete onboarding and go directly to auth
                        await ref.read(authProvider.notifier).completeOnboarding();
                        if (mounted) context.go('/auth');
                      },
                      child: Text(
                        'Skip Onboarding',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.onSurfaceVariant.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
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
}

class OnboardingSlide {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String stepText;

  OnboardingSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.stepText,
  });
}
