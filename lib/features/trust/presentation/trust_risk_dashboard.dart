import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/data/repository.dart';

class TrustRiskDashboard extends ConsumerStatefulWidget {
  const TrustRiskDashboard({super.key});

  @override
  ConsumerState<TrustRiskDashboard> createState() => _TrustRiskDashboardState();
}

class _TrustRiskDashboardState extends ConsumerState<TrustRiskDashboard> {
  bool _isLoading = true;
  String? _error;
  User? _currentUser;
  List<Escrow> _userEscrows = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      final user = await repo.getCurrentUser();
      final escrows = await repo.getEscrowContracts(user.currentRole);
      setState(() {
        _currentUser = user;
        _userEscrows = escrows;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = _currentUser?.currentRole ?? 'customer';
    final isMerchant = role == 'merchant';

    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(child: LoadingStateView()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Trust & Reputation Score',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
            onPressed: () => context.canPop() ? context.pop() : context.go(isMerchant ? '/merchant/home' : '/customer/home'),
          ),
        ),
        body: ErrorStateView(
          title: 'Failed to load reputation dashboard',
          description: _error!,
          onRetry: _fetchDashboardData,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Trust & Reputation Score',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () => context.canPop() ? context.pop() : context.go(isMerchant ? '/merchant/home' : '/customer/home'),
        ),
      ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTrustScoreHeader(isMerchant),
                  const SizedBox(height: 16),
                  _buildSafetyBadgesGrid(),
                  const SizedBox(height: 16),
                  _buildDisputeStatsCard(),
                  const SizedBox(height: 16),
                  _buildScoreBreakdownCard(),
                  const SizedBox(height: 16),
                  _buildReputationAuditCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildTrustScoreHeader(bool isMerchant) {
    // Determine dynamic trust score based on mock data
    final double trustScore = isMerchant ? 98.6 : 95.2;
    final ratingText = trustScore >= 95 ? 'Exceptional Peer Trust' : 'High Trust Rating';
    final color = trustScore >= 95 ? AppColors.tertiary : AppColors.primary;

    return BentoCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified, color: AppColors.primary, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      isMerchant ? 'MERCHANT PROTOCOL CREDENTIALS' : 'PEER COMMERCE CREDENTIALS',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _currentUser?.name ?? 'Alex Chen',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  ratingText,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Calculated via smart contract milestone releases, court vote alignment, and locked collateral history.',
                  style: TextStyle(fontSize: 10.5, color: AppColors.outline, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Circular progress or badge
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.aiGradient),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    trustScore.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const Text(
                    '/100',
                    style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyBadgesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cryptographic Trust Badges',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.8,
          children: [
            _buildBadgeCard('On-Chain Verified', 'Identities anchored to Cardano Native Assets.', Icons.shield, AppColors.primary),
            _buildBadgeCard('Zero Disputes', 'No milestone disputes raised in last 30 days.', Icons.stars_outlined, AppColors.tertiary),
            _buildBadgeCard('Collateral Audited', 'All active agreements hold pre-funded locks.', Icons.account_balance_wallet_outlined, AppColors.secondary),
            _buildBadgeCard('Consensus Aligned', 'Arbitration votes match peer jury outcomes.', Icons.people_outline, Colors.teal),
          ],
        ),
      ],
    );
  }

  Widget _buildBadgeCard(String title, String subtitle, IconData icon, Color col) {
    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: col.withValues(alpha: 0.08),
            child: Icon(icon, size: 14, color: col),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5)),
                Text(subtitle, style: const TextStyle(fontSize: 8, color: AppColors.outline), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisputeStatsCard() {
    final activeDisputes = _userEscrows.where((e) => e.status == 'Disputed').length;
    final totalEscrowSum = _userEscrows.fold(0.0, (sum, e) => sum + e.totalValue);

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Escrow Telemetry & Dispute Metrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('PROTECTED VALUE', '\$${totalEscrowSum.toStringAsFixed(0)}', AppColors.primary),
              _buildVerticalDivider(),
              _buildStatItem('ACTIVE DISPUTES', '$activeDisputes', activeDisputes > 0 ? AppColors.error : AppColors.tertiary),
              _buildVerticalDivider(),
              _buildStatItem('SUCCESS RESOLUTION', '100%', AppColors.tertiary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.outlineVariant.withValues(alpha: 0.3),
    );
  }

  Widget _buildStatItem(String label, String value, Color col) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.outline)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: col)),
      ],
    );
  }

  Widget _buildScoreBreakdownCard() {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reputation Score Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Divider(height: 24),
          _buildBreakdownRow('Milestone Payout Speed', 0.98, 'Very Fast'),
          _buildBreakdownRow('Audit Compliance Integrity', 1.0, 'Excellent'),
          _buildBreakdownRow('Consensus Verdict Accuracy', 0.92, 'Highly Aligned'),
          _buildBreakdownRow('Counterparty Communication Rating', 0.95, 'Helpful'),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String title, double score, String rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              Text('$rating (${(score * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score,
              backgroundColor: AppColors.outlineVariant.withValues(alpha: 0.2),
              color: AppColors.primary,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReputationAuditCard() {
    return BentoCard(
      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      color: AppColors.secondary.withValues(alpha: 0.04),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.secondary, size: 14),
              SizedBox(width: 6),
              Text('ZeroPay AI Assistant Audit Advice', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'To achieve a perfect 100/100 peer reputation score, deploy at least one additional multi-milestone contract using Cardano ADA pre-funded locks. Prompt consensus resolutions quickly to maximize your promptness score.',
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, height: 1.3),
          ),
        ],
      ),
    );
  }
}
