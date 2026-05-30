import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/providers/offline_provider.dart';

class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // User Header Profile Card
            _buildProfileHeader(context, user),
            const SizedBox(height: 24),

            // Connected Wallets
            _buildConnectedWallets(context),
            const SizedBox(height: 24),

            // Settings & Preferences
            _buildPreferences(context, ref, authState),
            const SizedBox(height: 24),

            // Security & Operations Hub
            _buildSecurityAndTestingHub(context, ref),
            const SizedBox(height: 24),

            // Sign out
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) {
                    context.go('/onboarding');
                  }
                },
                child: const Text('Sign Out Session', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, User? user) {
    return BentoCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.surfaceContainerHigh,
            backgroundImage: user?.profileImageUrl != null ? NetworkImage(user!.profileImageUrl!) : null,
            child: user?.profileImageUrl == null
                ? const Icon(Icons.person, size: 36, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user?.name ?? 'Alex Chen',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: AppColors.tertiary, size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'alex.chen@lumina.io',
                  style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 8),
                 // Trust Score
                 InkWell(
                   onTap: () => context.go('/trust/dashboard'),
                   borderRadius: BorderRadius.circular(12),
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                     decoration: BoxDecoration(
                       color: AppColors.tertiary.withOpacity(0.08),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: const [
                         Icon(Icons.shield_outlined, size: 12, color: AppColors.tertiary),
                         SizedBox(width: 4),
                         Text(
                           'Buyer Trust Score: 99.4%',
                           style: TextStyle(
                             fontSize: 10,
                             fontWeight: FontWeight.bold,
                             color: AppColors.tertiary,
                           ),
                         ),
                       ],
                     ),
                   ),
                 ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildConnectedWallets(BuildContext context) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Connected Ledgers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          _buildWalletRow('Cardano Native', '0x8f7c...d1e', true),
          const SizedBox(height: 10),
          _buildWalletRow('Arbitrum USDC', '0x2eca...a60', true),
          const SizedBox(height: 10),
          _buildWalletRow('Ethereum Mainnet', 'Not Connected', false),
        ],
      ),
    );
  }

  Widget _buildWalletRow(String label, String address, bool connected) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              connected ? Icons.link : Icons.link_off,
              color: connected ? AppColors.tertiary : AppColors.outline,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        Text(
          address,
          style: TextStyle(
            fontSize: 11,
            fontFamily: connected ? 'monospace' : null,
            color: connected ? AppColors.primary : AppColors.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildPreferences(BuildContext context, WidgetRef ref, AuthState authState) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Security Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Secure Enclave Biometrics', style: TextStyle(fontSize: 13)),
            subtitle: const Text('Unlock wallet and confirm escrows using FaceID', style: TextStyle(fontSize: 11)),
            contentPadding: EdgeInsets.zero,
            value: authState.user?.biometricsEnabled ?? true,
            activeColor: AppColors.primary,
            onChanged: (val) {
              ref.read(authProvider.notifier).setBiometricsEnabled(val);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Smart Escrow Push Alerts', style: TextStyle(fontSize: 13)),
            subtitle: const Text('Notify when sellers request milestone releases', style: TextStyle(fontSize: 11)),
            contentPadding: EdgeInsets.zero,
            value: true,
            activeColor: AppColors.primary,
            onChanged: (val) {},
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityAndTestingHub(BuildContext context, WidgetRef ref) {
    final offlineState = ref.watch(offlineProvider);

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Security & Operations Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.security, color: AppColors.primary),
            title: const Text('Security Center', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            subtitle: const Text('Manage FaceID locks, passcode setup, and active connected devices.', style: TextStyle(fontSize: 10)),
            trailing: const Icon(Icons.chevron_right, size: 16),
            onTap: () => context.go('/security-center'),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.store, color: AppColors.primary),
            title: const Text('App Store & Onboarding Assets', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            subtitle: const Text('Review store screenshots narrative layout, splash setups, and privacy policies.', style: TextStyle(fontSize: 10)),
            trailing: const Icon(Icons.chevron_right, size: 16),
            onTap: () => context.go('/onboarding/assets'),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Offline Resilience Mode', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            subtitle: const Text('Operate using secure local cache, offline transaction signing, and automatic synchronization.', style: TextStyle(fontSize: 10)),
            value: offlineState.isOffline,
            activeColor: AppColors.primary,
            onChanged: (val) {
              ref.read(offlineProvider.notifier).toggleConnection();
              if (val) {
                ref.read(offlineProvider.notifier).queueAction();
                ref.read(offlineProvider.notifier).queueAction();
              }
            },
          ),
        ],
      ),
    );
  }
}
