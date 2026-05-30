import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/presentation/widgets.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  int _selectedRoleIndex = 0; // 0: Customer, 1: Merchant, 2: Hybrid

  final List<RoleDetail> _roles = [
    RoleDetail(
      title: 'Customer Mode',
      subtitle: 'Safe buyer escrows & dispute protection',
      description: 'Fund contract milestones securely, negotiate terms with ZeroPay AI, and enjoy full on-chain dispute arbitration.',
      icon: Icons.person_outline,
      color: AppColors.primary,
      features: [
        'Trustless milestone escrows',
        'ZeroPay AI automated agent',
        'Jury dispute protection',
      ],
    ),
    RoleDetail(
      title: 'Merchant Mode',
      subtitle: 'Premium zero-chargeback commerce OS',
      description: 'Issue pre-funded smart invoices, monitor revenue with real-time analytics, and build your merchant trust reputation score.',
      icon: Icons.storefront_outlined,
      color: AppColors.secondary,
      features: [
        'Milestone-locked checkout',
        'Sales & volume dashboard',
        'Immutable trust reputation',
      ],
    ),
    RoleDetail(
      title: 'Hybrid Pro Workspace',
      subtitle: 'Buyer + Seller consolidated profile',
      description: 'Participate as both a contract buyer and verified merchant. Toggle workspaces in one tap with aggregated asset portfolios.',
      icon: Icons.all_inclusive,
      color: AppColors.tertiary,
      features: [
        'Instant workspace toggle',
        'Combined assets wallet',
        'Dual-role reputation tracking',
      ],
    ),
  ];

  void _handleRoleInitialization() async {
    final authNotifier = ref.read(authProvider.notifier);
    final role = _selectedRoleIndex == 1 ? 'merchant' : 'customer';
    
    await authNotifier.selectWorkspaceRole(role);
    if (mounted) {
      if (role == 'merchant') {
        context.go('/merchant/home');
      } else {
        context.go('/customer/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Workspace',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how you want to interact with the ZeroPay blockchain commerce network.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Intersecting interactive role cards
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                itemCount: _roles.length,
                itemBuilder: (context, index) {
                  final role = _roles[index];
                  final isSelected = _selectedRoleIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: BentoCard(
                      onTap: () {
                        setState(() {
                          _selectedRoleIndex = index;
                        });
                      },
                      color: isSelected
                          ? role.color.withOpacity(0.04)
                          : AppColors.surfaceContainerLowest,
                      border: Border.all(
                        color: isSelected
                            ? role.color
                            : AppColors.outlineVariant.withOpacity(0.3),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Icon container
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? role.color.withOpacity(0.12)
                                      : AppColors.surfaceContainerHigh.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  role.icon,
                                  color: isSelected ? role.color : AppColors.onSurfaceVariant,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      role.title,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? role.color : AppColors.onSurface,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      role.subtitle,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: AppColors.onSurfaceVariant.withOpacity(0.8),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              // Radio replacement dot
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? role.color : AppColors.outlineVariant,
                                    width: isSelected ? 6.0 : 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            role.description,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                  height: 1.3,
                                ),
                          ),
                          const SizedBox(height: 12),
                          // bullet items
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: role.features.map((feature) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 12,
                                    color: isSelected ? role.color : AppColors.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    feature,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                          fontSize: 10,
                                        ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Confirm Workspace button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: GradientButton(
                  text: 'Launch Workspace',
                  onPressed: _handleRoleInitialization,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoleDetail {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> features;

  RoleDetail({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.features,
  });
}
