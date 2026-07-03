import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/presentation/layout_shells.dart';
import '../../../shared/data/repository.dart';
import '../../trust/presentation/audit_release_gate.dart';

class EscrowDetailsScreen extends ConsumerStatefulWidget {
  final String escrowId;
  const EscrowDetailsScreen({required this.escrowId, super.key});

  @override
  ConsumerState<EscrowDetailsScreen> createState() => _EscrowDetailsScreenState();
}

class _EscrowDetailsScreenState extends ConsumerState<EscrowDetailsScreen> {
  bool _isLoading = false;
  bool _isPageLoading = true;
  String? _error;
  Escrow? _escrowState;
  List<dynamic> _githubAudits = [];

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isPageLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      final data = await repo.getEscrowDetails(widget.escrowId);
      List<dynamic> audits = [];
      if (data.projectPlanId != null) {
        try {
          audits = await repo.getProjectGitHubAudits(data.projectPlanId!);
        } catch (_) {
          // Fallback if route fails
        }
      }
      setState(() {
        _escrowState = data;
        _githubAudits = audits;
        _isPageLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isPageLoading = false;
      });
    }
  }

  void _handleReleaseMilestone(String milestoneId) async {
    setState(() => _isLoading = true);
    final repo = ref.read(zeroPayRepositoryProvider);
    await repo.releaseMilestone(widget.escrowId, milestoneId);
    
    // Fetch updated details
    final updated = await repo.getEscrowDetails(widget.escrowId);
    if (mounted) {
      setState(() {
        _escrowState = updated;
        _isLoading = false;
      });

      // Show Success Dialog
      showDialog(
        context: context,
        builder: (context) => const SuccessDialog(
          title: 'Milestone Released',
          description: 'Funds have been cryptographically unlocked and transferred to the seller address.',
        ),
      );
    }
  }

  void _handleRaiseDispute() async {
    setState(() => _isLoading = true);
    final repo = ref.read(zeroPayRepositoryProvider);
    await repo.raiseDispute(widget.escrowId);

    // Fetch updated details
    final updated = await repo.getEscrowDetails(widget.escrowId);
    if (mounted) {
      setState(() {
        _escrowState = updated;
        _isLoading = false;
      });

      // Show Error Dialog as alert notification
      ErrorDialog.show(
        context,
        title: 'Dispute Raised',
        description: 'Escrow contract has been frozen. Dispute Case filed to court for peer-consensus arbitration.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPageLoading) {
      return const Scaffold(
        body: SafeArea(child: LoadingStateView()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
            onPressed: () => context.canPop() ? context.pop() : context.go('/customer/escrow'),
          ),
          title: Text(
            'Escrow Details #${widget.escrowId}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface),
          ),
        ),
        body: ErrorStateView(
          title: 'Failed to load escrow details',
          description: _error!,
          onRetry: _fetchDetails,
        ),
      );
    }

    final escrow = _escrowState!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => context.canPop() ? context.pop() : context.go('/customer/escrow'),
        ),
        title: Text(
          'Escrow Details #${escrow.id}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              // Value Header
              _buildValueHeader(escrow),
              const SizedBox(height: 24),

              // GitHub AI Audit Card
              AuditReleaseGate(
                audit: _githubAudits.isNotEmpty ? Map<String, dynamic>.from(_githubAudits.first) : null,
                isLoading: false,
                projectPlanId: escrow.projectPlanId,
              ),
              if (escrow.projectPlanId != null) const SizedBox(height: 24),

              // Milestones Vertical Timeline Stepper
              _buildMilestonesStepper(escrow),
              const SizedBox(height: 24),

              // Contract & Details Table
              _buildDetailsTable(escrow),
              const SizedBox(height: 24),

              // Security & Trust badge
              _buildSecurityBadge(),
              const SizedBox(height: 24),

              // Actions
              _buildActionButtons(escrow),
              const SizedBox(height: 48),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildValueHeader(Escrow escrow) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(escrow.status).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _getStatusColor(escrow.status).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 12, color: _getStatusColor(escrow.status)),
              const SizedBox(width: 4),
              Text(
                'Status: ${escrow.status}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(escrow.status),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${escrow.totalValue} ${escrow.assetSymbol}',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '≈ \$${(escrow.totalValue * (escrow.assetSymbol == 'ADA' ? 0.40 : 1.00)).toStringAsFixed(2)} USD',
          style: const TextStyle(color: AppColors.outline, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildMilestonesStepper(Escrow escrow) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Milestones Timeline',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 20),
          Column(
            children: List.generate(escrow.milestones.length, (index) {
              final m = escrow.milestones[index];
              final isLast = index == escrow.milestones.length - 1;
              final isReleased = m.status == 'Released';
              final isInProgress = m.status == 'In Progress';

              final milestoneAudits = _githubAudits.where((a) => a['milestoneId'] == m.id).toList();
              final latestAudit = milestoneAudits.isNotEmpty ? milestoneAudits.first : null;
              final score = latestAudit != null ? (latestAudit['releaseConfidenceScore'] as num?)?.toDouble() ?? 0.0 : 0.0;
              final status = latestAudit != null ? latestAudit['auditStatus'] as String? ?? 'FAILED' : 'FAILED';
              final isPassed = status == 'PASSED' && score >= 70.0;
              final canRelease = escrow.projectPlanId == null || isPassed;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stepper timeline line/dot
                    Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isReleased
                                ? AppColors.tertiary
                                : isInProgress
                                    ? Colors.transparent
                                    : AppColors.surfaceContainerHigh,
                            border: isInProgress
                                ? Border.all(color: AppColors.primary, width: 2)
                                : null,
                          ),
                          child: isReleased
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : isInProgress
                                  ? Center(
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                            color: AppColors.primary, shape: BoxShape.circle,),
                                      ),
                                    )
                                  : null,
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: isReleased ? AppColors.tertiary : AppColors.surfaceContainerHigh,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  m.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isReleased ? AppColors.onSurface : AppColors.onSurfaceVariant,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getMilestoneColor(m.status).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    m.status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _getMilestoneColor(m.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              m.description,
                              style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Amount: ${m.amount} ${escrow.assetSymbol}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),

                            // If "In Progress" or requested release, show release CTA
                            if (isInProgress) ...[
                              const SizedBox(height: 12),
                              // Lumina recommendation bubble
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.auto_awesome, color: AppColors.secondary, size: 14),
                                        SizedBox(width: 6),
                                        Text('ZeroPay AI Assistant',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Seller completed the Design tasks. Code deliverables verified inside Github repository. Safe to release.',
                                      style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                    ),
                                    const SizedBox(height: 8),
                                    if (canRelease)
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                          minimumSize: const Size(0, 28),
                                          backgroundColor: AppColors.primary,
                                        ),
                                        onPressed: () => _handleReleaseMilestone(m.id),
                                        child: const Text('Release Milestone',
                                            style: TextStyle(fontSize: 11, color: Colors.white),),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.lock, size: 12, color: AppColors.error),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Release Locked (Score: ${score.toInt()}%)',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.error),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTable(Escrow escrow) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contract Information', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildDetailRow('Merchant', escrow.counterpartyName),
          _buildDetailRow('Chain Network', escrow.chainName),
          _buildDetailRow('Smart Contract', escrow.contractAddress, isAddress: true),
          _buildDetailRow('Filing Date', 'May 24, 2026'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAddress = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
          Row(
            children: [
              Text(
                isAddress ? '${value.substring(0, 6)}...${value.substring(value.length - 4)}' : value,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: isAddress ? 'monospace' : null,
                  fontWeight: FontWeight.bold,
                  color: isAddress ? AppColors.primary : AppColors.onSurface,
                ),
              ),
              if (isAddress) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Contract address copied.')),
                    );
                  },
                  child: const Icon(Icons.copy, size: 12, color: AppColors.outline),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityBadge() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tertiary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.15)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield, color: AppColors.tertiary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Milestone Protection Active. Vault deposits are cryptographically managed. Neither party can recover funds without mutual signature or court ruling.',
              style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Escrow escrow) {
    final isDisputed = escrow.status == 'Disputed';
    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
              ),
            ),
             onPressed: () {
               context.push('/customer/chat?invoiceId=${widget.escrowId}');
             },
             icon: const Icon(Icons.chat_bubble_outline, size: 16),
             label: const Text('Chat'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: isDisputed ? AppColors.surfaceContainerHigh : AppColors.errorContainer,
              foregroundColor: isDisputed ? AppColors.outline : AppColors.onErrorContainer,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: isDisputed ? null : _handleRaiseDispute,
            icon: const Icon(Icons.gavel, size: 16),
            label: Text(isDisputed ? 'In Court' : 'Dispute'),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'Locked' || status == 'Active') return AppColors.primary;
    if (status == 'Released' || status == 'Completed') return AppColors.tertiary;
    if (status == 'Disputed') return AppColors.error;
    return Colors.orange;
  }

  Color _getMilestoneColor(String status) {
    if (status == 'Released') return AppColors.tertiary;
    if (status == 'In Progress') return AppColors.primary;
    return AppColors.outline;
  }
}
