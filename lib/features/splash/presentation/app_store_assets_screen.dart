import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/widgets.dart';

class AppStoreAssetsScreen extends ConsumerStatefulWidget {
  const AppStoreAssetsScreen({super.key});

  @override
  ConsumerState<AppStoreAssetsScreen> createState() => _AppStoreAssetsScreenState();
}

class _AppStoreAssetsScreenState extends ConsumerState<AppStoreAssetsScreen> {
  int _activePermissionStep = 0; // 0: None, 1: FaceID, 2: Push Notifications, 3: Completed

  void _requestFaceId() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.face, size: 24, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Allow "ZeroPay" to use Face ID?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        content: const Text(
          'Allow biometric authentication to secure wallet transactions and instant milestone releases.',
          style: TextStyle(fontSize: 11.5, color: AppColors.outline),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Don\'t Allow'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _activePermissionStep = 2);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('FaceID biometrics authorization granted.')),
              );
            },
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }

  void _requestNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.notifications_active_outlined, size: 24, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Allow "ZeroPay" to send Notifications?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        content: const Text(
          'Notifications may include alerts, sounds, and icon badges. Get instant alerts when counterparty releases funds or files disputes.',
          style: TextStyle(fontSize: 11.5, color: AppColors.outline),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Don\'t Allow'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _activePermissionStep = 3);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Push notifications permission granted.')),
              );
            },
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('App Store & Launch Assets', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.onBackground),
          onPressed: () => context.go('/customer/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSplashHeader(),
          const SizedBox(height: 16),
          _buildScreenshotPlanPanel(),
          const SizedBox(height: 16),
          _buildPermissionFlowCard(),
          const SizedBox(height: 16),
          _buildTermsPrivacyCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSplashHeader() {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ZeroPay Brand Identity Assets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              // Logo mock icon visual
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.aiGradient),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.all_inclusive, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('ZeroPay App Icon (Standard Store iOS/Android)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    SizedBox(height: 4),
                    Text('Scale: 1024x1024 px. Design features Lumina AI continuous glow sweep over vector geometry lines.', style: TextStyle(fontSize: 10, color: AppColors.outline, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text('Launch Splash Sequence Outline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          _buildTimelineSplashStep('0.0s', 'Secure Enclave Handshake', 'Initialize local cryptographic key stores.'),
          _buildTimelineSplashStep('0.8s', 'Lumina Core Sync', 'Open WebSockets channel, sync block height validation.'),
          _buildTimelineSplashStep('1.5s', 'Session Handshake', 'Authorize biometric tokens, bypass auth to dashboard.'),
        ],
      ),
    );
  }

  Widget _buildTimelineSplashStep(String timestamp, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(timestamp, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: AppColors.primary, fontFamily: 'monospace')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                Text(subtitle, style: const TextStyle(fontSize: 9.5, color: AppColors.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenshotPlanPanel() {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('App Store Screenshot Narrative Board', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 12),
          _buildScreenshotPlanRow('1. Home Dashboard', 'Title: "Blockchain Commerce OS"', 'Visual: Networth, wallets, active protected escrows, system sync logs.'),
          _buildScreenshotPlanRow('2. Secure Chat', 'Title: "Trustless Milestone Contracts"', 'Visual: Timelines, payment locked invoice bubbles, AI audit alerts.'),
          _buildScreenshotPlanRow('3. AI Negotiation', 'Title: "Interactive Price Negotiations"', 'Visual: Counter-offer slider, agreement probability arcs, audits.'),
          _buildScreenshotPlanRow('4. Consensus Court', 'Title: "Decentralized Dispute Court"', 'Visual: Juror panels, consensus leaning curves, file ledger.'),
        ],
      ),
    );
  }

  Widget _buildScreenshotPlanRow(String stepName, String titleLabel, String visualDesc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stepName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primary)),
          Text(titleLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
          Text(visualDesc, style: const TextStyle(fontSize: 10, color: AppColors.outline)),
        ],
      ),
    );
  }

  Widget _buildPermissionFlowCard() {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Permissions Flow Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 6),
          const Text('User authorization flows required on first launch setup.', style: TextStyle(fontSize: 10, color: AppColors.outline)),
          const Divider(height: 20),
          if (_activePermissionStep == 0) ...[
            Center(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  setState(() => _activePermissionStep = 1);
                },
                icon: const Icon(Icons.playlist_play),
                label: const Text('Start Authorization Flow', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ] else if (_activePermissionStep == 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Face ID Authorization', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: _requestFaceId,
                  child: const Text('Trigger FaceID Prompt', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ] else if (_activePermissionStep == 2) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Push Alerts Permission', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: _requestNotifications,
                  child: const Text('Trigger Alerts Prompt', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.tertiary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle, color: AppColors.tertiary, size: 16),
                  SizedBox(width: 8),
                  Text('All core permissions completed.', style: TextStyle(color: AppColors.tertiary, fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTermsPrivacyCard() {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Terms & Privacy Agreements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 12),
          Container(
            height: 120,
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('ZEROPAY COMMERCE PROTOCOL TERMS OF SERVICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5)),
                  SizedBox(height: 6),
                  Text(
                    '1. By deploying or pre-funding escrows on the ZeroPay platform, you authorize peer consensus court nodes to adjudicate disputes in event of active timeline block locks.\n'
                    '2. Funds locked in escrow agreements remain on-chain in smart contracts. ZeroPay developers do not hold custodial keys.\n'
                    '3. Juror consensus results trigger automated code payout releases and are non-refundable.\n'
                    '4. Privacy: IPFS evidence hash logs are public parameters. Do not upload plaintext sensitive personal documents.',
                    style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant, height: 1.3),
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
