import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/data/repository.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/providers/global_providers.dart';

class SecurityCenterScreen extends ConsumerStatefulWidget {
  const SecurityCenterScreen({super.key});

  @override
  ConsumerState<SecurityCenterScreen> createState() => _SecurityCenterScreenState();
}

class _SecurityCenterScreenState extends ConsumerState<SecurityCenterScreen> {
  bool _biometricsEnabled = true;
  bool _passcodeEnabled = false;
  bool _requireConfirmations = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        setState(() {
          _biometricsEnabled = user.biometricsEnabled;
        });
      }
    });
  }
  
  final List<Map<String, String>> _connectedDevices = [
    {'device': 'iPhone 15 Pro Max (This Device)', 'ip': '192.168.1.45', 'location': 'San Francisco, USA', 'status': 'ActiveNow'},
    {'device': 'MacBook Pro 16"', 'ip': '192.168.1.12', 'location': 'San Francisco, USA', 'status': 'Active 2h ago'},
    {'device': 'iPad Pro 11"', 'ip': '192.168.1.9', 'location': 'New York, USA', 'status': 'Inactive'},
  ];

  final List<Map<String, String>> _loginHistory = [
    {'timestamp': '2026-05-29 22:15:30', 'ip': '192.168.1.45', 'status': 'Success', 'action': 'Biometric login'},
    {'timestamp': '2026-05-28 14:02:11', 'ip': '192.168.1.12', 'status': 'Success', 'action': 'Web Auth Token sync'},
    {'timestamp': '2026-05-27 09:44:00', 'ip': '192.168.1.9', 'status': 'Success', 'action': 'Passcode auth'},
    {'timestamp': '2026-05-26 18:30:12', 'ip': '198.51.100.4', 'status': 'Blocked', 'action': 'Invalid key signature'},
  ];

  void _showPasscodeSetup() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Setup Local Secure Passcode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter a 4-digit passcode pin for offline local device trust verification.',
              style: TextStyle(fontSize: 12, color: AppColors.outline),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '••••',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (controller.text.length == 4) {
                setState(() => _passcodeEnabled = true);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Secure Passcode setup completed.')),
                );
              }
            },
            child: const Text('Confirm PIN'),
          ),
        ],
      ),
    );
  }

  void _simulateSensitiveActionConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Confirm Sensitive Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'You are authorizing an instant milestone fund release of 1500 USDC to DevCo Solutions. Secure Enclave biometric authorization requested.',
          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Decline'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sensitive action authorized via Secure Enclave.')),
              );
            },
            child: const Text('Authenticate FaceID'),
          ),
        ],
      ),
    );
  }

  void _simulateSessionTimeout() {
    setState(() => _isLoading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Simulating inactive session lock...')),
    );
    Future.delayed(const Duration(seconds: 1)).then((_) {
      if (mounted) {
        ref.read(authProvider.notifier).signOut();
        context.go('/auth');
      }
    });
  }

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final role = ref.read(authProvider).currentRole;
    final isMerchant = role == 'merchant';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Security & Trust Center',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () => context.canPop() ? context.pop() : context.go(isMerchant ? '/merchant/profile' : '/customer/profile'),
        ),
      ),
      body: _isLoading
          ? const SafeArea(child: LoadingStateView())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildSystemLockAlert(),
                const SizedBox(height: 16),
                _buildTrustShieldPanel(),
                const SizedBox(height: 16),
                _buildBiometricsToggles(),
                const SizedBox(height: 16),
                _buildConnectedDevicesPanel(),
                const SizedBox(height: 16),
                _buildLoginHistoryLogs(),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildSystemLockAlert() {
    return BentoCard(
      border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.3)),
      color: AppColors.tertiary.withValues(alpha: 0.04),
      child: const Row(
        children: [
          Icon(Icons.verified_user, color: AppColors.tertiary, size: 28),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local Security Enclave Status: Locked & Cryptographed',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.tertiary),
                ),
                SizedBox(height: 4),
                Text(
                  'All cryptographic keys and private mnemonics are stored within the native device secure enclave. ZeroPay servers hold zero custody of your private parameters.',
                  style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustShieldPanel() {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Device Security Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _simulateSensitiveActionConfirmation,
                  icon: const Icon(Icons.fingerprint, size: 16, color: AppColors.primary),
                  label: const Text('Verify Biometrics', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _simulateSessionTimeout,
                  icon: const Icon(Icons.timer_off_outlined, size: 16, color: Colors.white),
                  label: const Text('Session Timeout', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricsToggles() {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Secure Enclave & Local Locks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('FaceID / TouchID Biometrics', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
            subtitle: const Text('Unlock credentials using biometric checks.', style: TextStyle(fontSize: 10, color: AppColors.outline)),
            value: _biometricsEnabled,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) async {
              setState(() => _biometricsEnabled = val);
              try {
                final repo = ref.read(zeroPayRepositoryProvider);
                await repo.setBiometricsEnabled(val);
                ref.read(authProvider.notifier).setBiometricsEnabled(val);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Biometrics updated successfully to $val.')),
                  );
                }
              } catch (_) {
                setState(() => _biometricsEnabled = !val);
              }
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Require PIN Passcode Lock', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
            subtitle: const Text('Fallback authentication if biometrics fails.', style: TextStyle(fontSize: 10, color: AppColors.outline)),
            value: _passcodeEnabled,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              if (val) {
                _showPasscodeSetup();
              } else {
                setState(() => _passcodeEnabled = false);
              }
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Require Confirmations for Payouts', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
            subtitle: const Text('Prompt auth overlays for sensitive milestone releases.', style: TextStyle(fontSize: 10, color: AppColors.outline)),
            value: _requireConfirmations,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              setState(() => _requireConfirmations = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedDevicesPanel() {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Connected Wallet Sessions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 12),
          ..._connectedDevices.map((device) {
            final isActive = device['status'] == 'ActiveNow';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Icon(
                    device['device']!.contains('MacBook') ? Icons.laptop : Icons.phone_iphone,
                    color: isActive ? AppColors.tertiary : AppColors.outline,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(device['device']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('IP: ${device['ip']} | Loc: ${device['location']}', style: const TextStyle(color: AppColors.outline, fontSize: 9.5)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.tertiary.withValues(alpha: 0.08) : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      device['status']!,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: isActive ? AppColors.tertiary : AppColors.outline,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLoginHistoryLogs() {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Secured Login Event Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const Divider(height: 24),
          ..._loginHistory.map((history) {
            final isBlocked = history['status'] == 'Blocked';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(history['action']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      Text('IP: ${history['ip']} | Timestamp: ${history['timestamp']}', style: const TextStyle(color: AppColors.outline, fontSize: 9)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isBlocked ? AppColors.error.withValues(alpha: 0.08) : AppColors.tertiary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      history['status']!,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: isBlocked ? AppColors.error : AppColors.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
