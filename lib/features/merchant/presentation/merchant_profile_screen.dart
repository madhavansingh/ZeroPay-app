import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/providers/offline_provider.dart';

class MerchantProfileScreen extends ConsumerStatefulWidget {
  const MerchantProfileScreen({super.key});

  @override
  ConsumerState<MerchantProfileScreen> createState() => _MerchantProfileScreenState();
}

class _MerchantProfileScreenState extends ConsumerState<MerchantProfileScreen> {
  final TextEditingController _webhookUrlController = TextEditingController(text: 'https://api.merchant.io/webhooks');
  bool _webhookActive = true;
  bool _isWebhookFocused = false;
  String? _webhookError;

  @override
  void dispose() {
    _webhookUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Profile Header
            _buildProfileHeader(user),
            const SizedBox(height: 24),

            // Connected Wallets
            _buildConnectedWallets(),
            const SizedBox(height: 24),

            // Webhook Configuration
            _buildWebhookConfigPanel(),
            const SizedBox(height: 24),

            // Settings & Preferences
            _buildPreferences(authState),
            const SizedBox(height: 24),

            // Security & Operations Hub
            _buildSecurityAndTestingHub(context),
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

  Widget _buildProfileHeader(User? user) {
    return BentoCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.surfaceContainerHigh,
            backgroundImage: user?.profileImageUrl != null ? NetworkImage(user!.profileImageUrl!) : null,
            child: user?.profileImageUrl == null
                ? const Icon(Icons.person, size: 36, color: AppColors.secondary)
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
                  user?.email ?? 'merchant@cryptobrews.eth',
                  style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 8),
                // Verification Badges
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
                          'Merchant Verified: Active',
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

  Widget _buildConnectedWallets() {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settlement Ledger Wallets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          _buildWalletRow('Cardano Treasury Wallet', '0x8f7c...d1e'),
          const SizedBox(height: 10),
          _buildWalletRow('Arbitrum USDC Wallet', '0x2eca...a60'),
        ],
      ),
    );
  }

  Widget _buildWalletRow(String label, String address) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.link, color: AppColors.tertiary, size: 16),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        Text(
          address,
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildWebhookConfigPanel() {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Webhook Integration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Switch(
                value: _webhookActive,
                activeColor: AppColors.secondary,
                onChanged: (val) => setState(() => _webhookActive = val),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Push transaction settlement and dispute events to your downstream servers.',
            style: TextStyle(fontSize: 11, color: AppColors.outline),
          ),
          const SizedBox(height: 12),
          if (_webhookActive) ...[
            Focus(
              onFocusChange: (hasFocus) {
                setState(() {
                  _isWebhookFocused = hasFocus;
                  if (!hasFocus) {
                    final url = _webhookUrlController.text.trim();
                    if (url.isEmpty) {
                      _webhookError = 'Webhook URL cannot be empty.';
                    } else if (!url.startsWith('https://')) {
                      _webhookError = 'Webhook endpoint must use secure HTTPS protocol.';
                    } else {
                      _webhookError = null;
                    }
                  }
                });
              },
              child: TextField(
                controller: _webhookUrlController,
                onChanged: (val) {
                  if (_webhookError != null) {
                    setState(() {
                      _webhookError = null;
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Webhook URL Endpoint',
                  hintText: 'https://yourdomain.com/webhooks',
                  labelStyle: const TextStyle(fontSize: 12),
                  errorText: _webhookError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _webhookError != null
                          ? AppColors.error
                          : _isWebhookFocused
                              ? AppColors.secondary
                              : AppColors.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.secondary, width: 2.0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _webhookError != null
                      ? null
                      : () {
                          final url = _webhookUrlController.text.trim();
                          if (url.isEmpty || !url.startsWith('https://')) {
                            setState(() {
                              _webhookError = 'Please provide a valid HTTPS URL first.';
                            });
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Test payload dispatched. Response: 200 OK')),
                          );
                        },
                  child: const Text('Send Test Event', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferences(AuthState authState) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Security Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Secure Enclave Biometrics', style: TextStyle(fontSize: 13)),
            subtitle: const Text('Unlock wallet and confirm payout releases using FaceID', style: TextStyle(fontSize: 11)),
            contentPadding: EdgeInsets.zero,
            value: authState.user?.biometricsEnabled ?? true,
            activeColor: AppColors.secondary,
            onChanged: (val) {
              ref.read(authProvider.notifier).setBiometricsEnabled(val);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Dispute Arbitration Alerts', style: TextStyle(fontSize: 13)),
            subtitle: const Text('Notify instantly if client delays milestones or files active dispute', style: TextStyle(fontSize: 11)),
            contentPadding: EdgeInsets.zero,
            value: true,
            activeColor: AppColors.secondary,
            onChanged: (val) {},
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityAndTestingHub(BuildContext context) {
    final offlineState = ref.watch(offlineProvider);

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Security & Operations Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.security, color: AppColors.secondary),
            title: const Text('Security Center', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            subtitle: const Text('Manage FaceID locks, passcode setup, and active connected devices.', style: TextStyle(fontSize: 10)),
            trailing: const Icon(Icons.chevron_right, size: 16),
            onTap: () => context.go('/security-center'),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.store, color: AppColors.secondary),
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
            activeColor: AppColors.secondary,
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
