import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/widgets.dart';

class AuditReleaseGate extends StatelessWidget {
  final Map<String, dynamic>? audit;
  final bool isLoading;
  final String? projectPlanId;

  const AuditReleaseGate({
    required this.audit,
    required this.isLoading,
    required this.projectPlanId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (projectPlanId == null) return const SizedBox.shrink();

    if (isLoading) {
      return const BentoCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (audit == null) {
      return BentoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GitHub Code Verification',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                GestureDetector(
                  onTap: () {
                    context.push('/trust/github-audit?projectPlanId=$projectPlanId');
                  },
                  child: const Row(
                    children: [
                      Text(
                        'Audit Dashboard',
                        style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'No audits have been executed yet. Payout release requests are locked until the code repository is connected and audited.',
              style: TextStyle(fontSize: 13, color: AppColors.error),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                context.push('/trust/github-audit?projectPlanId=$projectPlanId');
              },
              icon: const Icon(Icons.link, size: 16),
              label: const Text('Connect Repository & Run Audit', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    final score = (audit!['releaseConfidenceScore'] as num?)?.toDouble() ?? 0.0;
    final status = audit!['auditStatus'] as String? ?? 'FAILED';
    final recommendation = audit!['releaseRecommendation'] as String? ?? 'UNKNOWN';
    final commitHash = audit!['commitHash'] as String? ?? audit!['lastCommitHash'] as String?;
    final branch = audit!['branch'] as String? ?? 'main';
    final createdAt = audit!['createdAt'] as String?;

    final isPassed = status == 'PASSED' && score >= 70.0;

    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.warning;
    if (isPassed) {
      statusColor = AppColors.tertiary;
      statusIcon = Icons.check_circle;
    } else if (status == 'FAILED') {
      statusColor = AppColors.error;
      statusIcon = Icons.cancel;
    }

    String formattedDate = '';
    if (createdAt != null) {
      try {
        final parsed = DateTime.parse(createdAt);
        formattedDate = '${parsed.day}/${parsed.month}/${parsed.year} ${parsed.hour}:${parsed.minute}';
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GitHub AI Audit: ${isPassed ? "PASSED" : "FAILED"}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: statusColor),
              ),
              GestureDetector(
                onTap: () {
                  context.push('/trust/github-audit?auditId=${audit!['auditId']}&projectPlanId=$projectPlanId');
                },
                child: Row(
                  children: [
                    Text(
                      isPassed ? 'View Findings' : 'View Errors',
                      style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 8,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isPassed
                            ? AppColors.tertiary
                            : score >= 60
                                ? Colors.orange
                                : AppColors.error,
                      ),
                    ),
                  ),
                  Text(
                    '${score.toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Verdict: $status',
                          style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getRecommendationText(recommendation),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    if (commitHash != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Branch: $branch @ ${commitHash.length > 7 ? commitHash.substring(0, 7) : commitHash}',
                        style: const TextStyle(fontSize: 10, color: AppColors.outline, fontFamily: 'monospace'),
                      ),
                    ],
                    if (formattedDate.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Executed: $formattedDate',
                        style: const TextStyle(fontSize: 10, color: AppColors.outline),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getRecommendationText(String rec) {
    switch (rec) {
      case 'RECOMMEND_RELEASE':
        return 'Safe to release funds. High implementation coverage.';
      case 'RECOMMEND_MINOR_FIXES':
        return 'Minor fixes suggested, release at your discretion.';
      case 'RECOMMEND_MAJOR_REWORK':
        return 'Rework recommended. Crucial components are missing.';
      case 'RECOMMEND_DISPUTE_REVIEW':
        return 'Dispute review requested. Mismatch of requirements.';
      default:
        return 'Verification pending.';
    }
  }
}
