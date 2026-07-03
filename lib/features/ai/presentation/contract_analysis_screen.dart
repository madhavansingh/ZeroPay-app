import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/providers/global_providers.dart';

class ContractAnalysisScreen extends ConsumerWidget {
  const ContractAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataset = ref.watch(scenarioProfileProvider);

    // Dynamic stats based on active scenario profile
    double escrowConfidence = 96.0; // score out of 100
    int highRisks = 0;
    int medRisks = 1;
    int lowRisks = 2;
    String aiSummary = 'This contract locks 3,000.00 USDC in an escrow structure across 3 distinct milestones. The release triggers are controlled by the buyer, with automated git-commit inspections. Arbitration is delegated to the peer-consensus ZeroPay court in case of disputes.';
    switch (dataset) {
      case ScenarioProfile.smallMerchant:
        escrowConfidence = 98.0;
        highRisks = 0;
        medRisks = 0;
        lowRisks = 1;
        aiSummary = 'A simple, single-milestone escrow contract pre-funded on Arbitrum. Fully automated shipping scan receipt validation. Very high settlement confidence.';
        break;
      case ScenarioProfile.growingMerchant:
        escrowConfidence = 85.0;
        highRisks = 1;
        medRisks = 1;
        lowRisks = 3;
        aiSummary = 'Escrow contract integrates external API keys validation. One milestone (Figma designs) is frozen due to active customer dispute deliberations. Risk index is medium.';
        break;
      case ScenarioProfile.enterpriseMerchant:
        escrowConfidence = 99.0;
        highRisks = 0;
        medRisks = 2;
        lowRisks = 4;
        aiSummary = 'High-value multi-modal transport logistics route cargo escrow. Integrates multi-signature release triggers. Webhook delivery failure alerts detected downstream.';
        break;
      case ScenarioProfile.disputedTransaction:
        escrowConfidence = 45.0;
        highRisks = 3;
        medRisks = 2;
        lowRisks = 2;
        aiSummary = 'Dispute court is currently actively deliberating. High volume of conflicting evidence uploaded. Recommended to wait for consensus verdict findings.';
        break;
      default:
        break;
    }

    final clauses = [
      {'title': 'Milestone release trigger', 'desc': 'Buyer has sole cryptographic authority to release funds upon satisfying project requirements.', 'risk': 'Low'},
      {'title': 'Arbitration delegation', 'desc': 'Freezes contract funds and moves escrow ledger control to peer-consensus court in dispute scenarios.', 'risk': 'Low'},
      {'title': 'Appeal delay parameters', 'desc': 'Allows appealing juror verdicts once, locking funds in court for an additional 7 days.', 'risk': 'Medium'},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Contract Analyzer', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              final role = ref.read(authProvider).currentRole;
              context.go(role == 'merchant' ? '/merchant/dashboard' : '/customer/home');
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Score summary Bento
          _buildScoreOverview(escrowConfidence, highRisks, medRisks, lowRisks),
          const SizedBox(height: 20),

          // Overview AI Summary
          Text('Automated AI Contract Summary', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          BentoCard(
            padding: const EdgeInsets.all(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            color: AppColors.primary.withValues(alpha: 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                    SizedBox(width: 8),
                    Text('ZeroPay AI Analysis Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  aiSummary,
                  style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.onSurface),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Clause analysis
          Text('Analyzed Clauses & Smart Logic', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...clauses.map((c) {
            final isMed = c['risk'] == 'Medium';
            Color riskCol = isMed ? Colors.orange : AppColors.tertiary;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: BentoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(c['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: riskCol.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                          child: Text('${c['risk']} Risk', style: TextStyle(fontSize: 8, color: riskCol, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(c['desc']!, style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant, height: 1.3)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),

          // Suggestion fixes list
          BentoCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SUGGESTED OPTIMIZATIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.outline)),
                const SizedBox(height: 10),
                _buildFixRow(Icons.security, 'Require Multi-Signature verification verification for payout release keys.'),
                const SizedBox(height: 8),
                _buildFixRow(Icons.lock_clock, 'Reduce response validation timeout from 72h to 24h to accelerate pipeline flow.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreOverview(double confidence, int high, int med, int low) {
    return BentoCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Confidence Score', style: TextStyle(fontSize: 11, color: AppColors.outline, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${confidence.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 36)),
                    const SizedBox(width: 4),
                    const Text('/100', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                  ],
                ),
                Text(
                  confidence >= 90.0 ? 'Highly Secure Escrow' : 'Action Required',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: confidence >= 90.0 ? AppColors.tertiary : Colors.orange),
                ),
              ],
            ),
          ),
          Container(height: 80, width: 1, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Audit Risk Matrix', style: TextStyle(fontSize: 11, color: AppColors.outline, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildRiskMatrixRow('High issues', '$high', high > 0 ? AppColors.error : AppColors.outline),
                  const SizedBox(height: 4),
                  _buildRiskMatrixRow('Medium issues', '$med', med > 0 ? Colors.orange : AppColors.outline),
                  const SizedBox(height: 4),
                  _buildRiskMatrixRow('Low issues', '$low', AppColors.outline),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskMatrixRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
        Text(
          value,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildFixRow(IconData icon, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, height: 1.3),
          ),
        ),
      ],
    );
  }
}
