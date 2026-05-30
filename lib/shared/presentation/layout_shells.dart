import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../providers/global_providers.dart';
import '../providers/offline_provider.dart';
import 'widgets.dart';

// ============================================================================
// GLOBAL COMPONENT: Notification Center Sheet
// ============================================================================
class NotificationCenterSheet extends ConsumerWidget {
  const NotificationCenterSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationCenterSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);
    final notifier = ref.read(notificationProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return GlassPanel(
          radius: 24,
          backgroundColor: AppColors.surfaceContainerLowest.withOpacity(0.95),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (notifications.any((element) => !element.isRead))
                      TextButton(
                        onPressed: () {
                          for (var n in notifications) {
                            if (!n.isRead) notifier.markAsRead(n.id);
                          }
                        },
                        child: const Text('Mark all read'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: notifications.isEmpty
                      ? const Center(
                          child: Text('No new alerts.'),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final alert = notifications[index];
                            IconData icon = Icons.notifications_none;
                            Color iconColor = AppColors.primary;
                            if (alert.category == 'Security') {
                              icon = Icons.security;
                              iconColor = Colors.orange;
                            } else if (alert.category == 'Dispute') {
                              icon = Icons.gavel;
                              iconColor = Colors.red;
                            } else if (alert.category == 'Escrow') {
                              icon = Icons.lock;
                              iconColor = AppColors.tertiary;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: alert.isRead
                                    ? Colors.transparent
                                    : AppColors.primary.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: alert.isRead
                                      ? AppColors.outlineVariant.withOpacity(0.2)
                                      : AppColors.primary.withOpacity(0.15),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: iconColor.withOpacity(0.1),
                                  child: Icon(icon, color: iconColor),
                                ),
                                title: Text(
                                  alert.title,
                                  style: TextStyle(
                                    fontWeight: alert.isRead ? FontWeight.normal : FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(alert.description),
                                trailing: alert.isRead
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.done, size: 18),
                                        onPressed: () => notifier.markAsRead(alert.id),
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// GLOBAL COMPONENT: Custom Error Dialog
// ============================================================================
class ErrorDialog extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onConfirm;

  const ErrorDialog({
    required this.title,
    required this.description,
    this.onConfirm,
    super.key,
  });

  static void show(BuildContext context, {required String title, required String description}) {
    showDialog(
      context: context,
      builder: (context) => ErrorDialog(title: title, description: description),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0x1ABA1A1A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: AppColors.error, size: 32),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm?.call();
                },
                child: const Text('Dismiss'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CUSTOMER NAVIGATION SHELL
// ============================================================================
class CustomerShellLayout extends ConsumerWidget {
  final Widget child;
  const CustomerShellLayout({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;

    int currentIndex = 0;
    if (location.startsWith('/customer/marketplace')) currentIndex = 1;
    if (location.startsWith('/customer/escrow')) currentIndex = 2;
    if (location.startsWith('/customer/wallet')) currentIndex = 3;
    if (location.startsWith('/customer/profile')) currentIndex = 4;

    final offlineState = ref.watch(offlineProvider);

    return Scaffold(
      appBar: _buildShellAppBar(context, ref, 'customer'),
      body: Column(
        children: [
          if (offlineState.isOffline) _buildOfflineBanner(context, ref, offlineState),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3), width: 1.0)),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          elevation: 0,
          backgroundColor: AppColors.surfaceContainerLowest,
          indicatorColor: AppColors.primary.withOpacity(0.08),
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                context.go('/customer/home');
                break;
              case 1:
                context.go('/customer/marketplace');
                break;
              case 2:
                context.go('/customer/escrow');
                break;
              case 3:
                context.go('/customer/wallet');
                break;
              case 4:
                context.go('/customer/profile');
                break;
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront, color: AppColors.primary),
              label: 'Marketplace',
            ),
            NavigationDestination(
              icon: Icon(Icons.lock_outlined),
              selectedIcon: Icon(Icons.lock, color: AppColors.primary),
              label: 'Escrow',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet, color: AppColors.primary),
              label: 'Wallet',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MERCHANT NAVIGATION SHELL
// ============================================================================
class MerchantShellLayout extends ConsumerWidget {
  final Widget child;
  const MerchantShellLayout({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;

    int currentIndex = 0;
    if (location.startsWith('/merchant/store')) currentIndex = 1;
    if (location.startsWith('/merchant/escrows')) currentIndex = 2;
    if (location.startsWith('/merchant/analytics')) currentIndex = 3;
    if (location.startsWith('/merchant/profile')) currentIndex = 4;

    final offlineState = ref.watch(offlineProvider);

    return Scaffold(
      appBar: _buildShellAppBar(context, ref, 'merchant'),
      body: Column(
        children: [
          if (offlineState.isOffline) _buildOfflineBanner(context, ref, offlineState),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3), width: 1.0)),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          elevation: 0,
          backgroundColor: AppColors.surfaceContainerLowest,
          indicatorColor: AppColors.secondary.withOpacity(0.08),
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                context.go('/merchant/dashboard');
                break;
              case 1:
                context.go('/merchant/store');
                break;
              case 2:
                context.go('/merchant/escrows');
                break;
              case 3:
                context.go('/merchant/analytics');
                break;
              case 4:
                context.go('/merchant/profile');
                break;
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: AppColors.secondary),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.store_outlined),
              selectedIcon: Icon(Icons.store, color: AppColors.secondary),
              label: 'Store',
            ),
            NavigationDestination(
              icon: Icon(Icons.lock_person_outlined),
              selectedIcon: Icon(Icons.lock_person, color: AppColors.secondary),
              label: 'Escrows',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics, color: AppColors.secondary),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.secondary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// APP BAR GENERATOR (SHARED BETWEEN SHELLS WITH INSTANT WORKSPACE TOGGLER)
// ============================================================================
PreferredSizeWidget _buildShellAppBar(BuildContext context, WidgetRef ref, String mode) {
  final isMerchant = mode == 'merchant';
  final notificationCount = ref.watch(notificationProvider).where((n) => !n.isRead).length;

  return AppBar(
    elevation: 0,
    backgroundColor: AppColors.surfaceContainerLowest,
    title: Row(
      children: [
        Icon(
          Icons.all_inclusive,
          color: isMerchant ? AppColors.secondary : AppColors.primary,
          size: 26,
        ),
        const SizedBox(width: 8),
        Text(
          'ZeroPay',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isMerchant ? AppColors.secondary : AppColors.primary,
              ),
        ),
      ],
    ),
    actions: [
      // 1. Command Palette / Search Trigger
      IconButton(
        icon: const Icon(Icons.search, color: AppColors.onSurfaceVariant),
        onPressed: () => CommandPaletteSheet.show(context),
      ),

      // 2. Notification Center Badge Button
      Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.onSurfaceVariant),
            onPressed: () => NotificationCenterSheet.show(context),
          ),
          if (notificationCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 14,
                  minHeight: 14,
                ),
                child: Text(
                  '$notificationCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),

      // 3. Workspace Context Toggle (Hybrid Mode switcher)
      // Check if dataset is hybridPowerUser or just allow instant workspace switching for debugging convenience
      Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            side: BorderSide(
              color: isMerchant ? AppColors.secondary : AppColors.primary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () async {
            await ref.read(authProvider.notifier).switchWorkspaceRole();
            if (context.mounted) {
              if (isMerchant) {
                // Switch to customer
                context.go('/customer/home');
              } else {
                // Switch to merchant
                context.go('/merchant/dashboard');
              }
            }
          },
          icon: Icon(
            Icons.swap_horiz,
            size: 14,
            color: isMerchant ? AppColors.secondary : AppColors.primary,
          ),
          label: Text(
            isMerchant ? 'Seller' : 'Buyer',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isMerchant ? AppColors.secondary : AppColors.primary,
            ),
          ),
        ),
      ),
    ],
  );
}

// Temporary alias provider for auth state watching
final authStateProvider = Provider<AuthState>((ref) => ref.watch(authProvider));

Widget _buildOfflineBanner(BuildContext context, WidgetRef ref, OfflineState state) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.error.withOpacity(0.08),
      border: const Border(bottom: BorderSide(color: AppColors.error, width: 0.5)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        const Icon(Icons.cloud_off, size: 16, color: AppColors.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Device Offline | ${state.queuedActionsCount} actions queued',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
          ),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            minimumSize: const Size(0, 24),
            side: const BorderSide(color: AppColors.error),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Syncing queued actions to smart contract...')),
            );
            ref.read(offlineProvider.notifier).syncQueue();
          },
          child: const Text(
            'Force Sync',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.error),
          ),
        ),
      ],
    ),
  );
}
