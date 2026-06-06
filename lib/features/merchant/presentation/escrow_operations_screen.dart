import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/data/repository.dart';
import '../../../shared/providers/global_providers.dart';

class EscrowOperationsScreen extends ConsumerStatefulWidget {
  const EscrowOperationsScreen({super.key});

  @override
  ConsumerState<EscrowOperationsScreen> createState() => _EscrowOperationsScreenState();
}

class _EscrowOperationsScreenState extends ConsumerState<EscrowOperationsScreen> {
  Escrow? _selectedEscrow;
  final TextEditingController _evidenceController = TextEditingController();
  bool _isSubmitting = false;
  List<dynamic> _githubAudits = [];
  bool _isLoadingAudits = false;

  @override
  void dispose() {
    _evidenceController.dispose();
    super.dispose();
  }

  void _selectEscrow(Escrow escrow) async {
    setState(() {
      _selectedEscrow = escrow;
      _githubAudits = [];
      _isLoadingAudits = true;
    });
    if (escrow.projectPlanId != null) {
      try {
        final repo = ref.read(zeroPayRepositoryProvider);
        final audits = await repo.getProjectGitHubAudits(escrow.projectPlanId!);
        setState(() {
          _githubAudits = audits;
          _isLoadingAudits = false;
        });
      } catch (_) {
        setState(() => _isLoadingAudits = false);
      }
    } else {
      setState(() => _isLoadingAudits = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(zeroPayRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Escrow Operations Center', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () {
            if (_selectedEscrow != null) {
              setState(() {
                _selectedEscrow = null;
                _githubAudits = [];
                _isLoadingAudits = false;
              });
            } else {
              context.go('/merchant/dashboard');
            }
          },
        ),
      ),
      body: _selectedEscrow == null
          ? _buildEscrowListBody(repository)
          : _buildEscrowDetailsBody(repository, _selectedEscrow!),
    );
  }

  Widget _buildEscrowListBody(ZeroPayRepository repository) {
    final escrowAsync = ref.watch(merchantEscrowsProvider);
    return escrowAsync.when(
      loading: () => const LoadingStateView(),
      error: (err, stack) => ErrorStateView(
        title: 'Error loading escrows',
        description: err.toString(),
        onRetry: () => ref.invalidate(merchantEscrowsProvider),
      ),
      data: (escrows) {
        if (escrows.isEmpty) {
          return EmptyStateView(
            icon: Icons.lock_clock,
            title: 'No Active Contracts',
            description: 'Escrow contracts from buyers will appear here once created.',
            buttonText: 'Manage Storefront',
            onButtonPressed: () => context.push('/merchant/store'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: escrows.length,
          itemBuilder: (context, index) {
            final escrow = escrows[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: BentoCard(
                onTap: () => _selectEscrow(escrow),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(escrow.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        _buildStatusBadge(escrow.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Client: ${escrow.counterpartyName}', style: const TextStyle(fontSize: 11, color: AppColors.outline)),
                        Text(
                          '${escrow.totalValue} ${escrow.assetSymbol}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Milestones: ${escrow.milestones.length}', style: const TextStyle(fontSize: 10, color: AppColors.outline)),
                        const Text('Manage Contract →', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEscrowDetailsBody(ZeroPayRepository repository, Escrow escrow) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top Contract Card Summary
        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusBadge(escrow.status),
                  Text(
                    '${escrow.totalValue} ${escrow.assetSymbol}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.secondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(escrow.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Contract ID: ${escrow.id}', style: const TextStyle(fontSize: 10, color: AppColors.outline)),
              Text('Blockchain Address: ${escrow.contractAddress}', style: const TextStyle(fontSize: 10, color: AppColors.outline)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: AppColors.outline),
                  const SizedBox(width: 6),
                  Text('Client Account: ${escrow.counterpartyAddress}', style: const TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // GitHub AI Audit Panel
        if (escrow.projectPlanId != null) ...[
          _buildMerchantAuditStatusCard(escrow),
          const SizedBox(height: 20),
        ],

        // Milestone Manager Panel
        Text('Milestone Progression Manager', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        BentoCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: escrow.milestones.map((m) {
              final isReleased = m.status == 'Released';
              final isInProgress = m.status == 'In Progress';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isReleased
                      ? AppColors.tertiary.withOpacity(0.04)
                      : isInProgress
                          ? AppColors.primary.withOpacity(0.04)
                          : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isReleased
                        ? AppColors.tertiary.withOpacity(0.2)
                        : isInProgress
                            ? AppColors.primary.withOpacity(0.2)
                            : AppColors.outlineVariant.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isReleased
                          ? Icons.check_circle
                          : isInProgress
                              ? Icons.pending
                              : Icons.radio_button_unchecked,
                      color: isReleased
                          ? AppColors.tertiary
                          : isInProgress
                              ? AppColors.primary
                              : AppColors.outline,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          if (m.description.isNotEmpty)
                            Text(m.description, style: const TextStyle(fontSize: 10, color: AppColors.outline)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${m.amount} ${escrow.assetSymbol}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        if (isInProgress) ...[
                          if (_isLoadingAudits)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (_githubAudits.isEmpty && escrow.projectPlanId != null)
                            const Text(
                              'Audit Req.',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.error),
                            )
                          else
                            Builder(
                              builder: (context) {
                                final latestAudit = _githubAudits.isNotEmpty ? _githubAudits.first : null;
                                final score = latestAudit != null ? (latestAudit['releaseConfidenceScore'] as num?)?.toDouble() ?? 0.0 : 0.0;
                                final status = latestAudit != null ? latestAudit['auditStatus'] as String? ?? 'FAILED' : 'FAILED';
                                final canRequest = status == 'PASSED' && score >= 70.0;
                                
                                if (!canRequest && escrow.projectPlanId != null) {
                                  return Text(
                                    'Blocked (${score.toInt()}%)',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.error),
                                  );
                                }
                                
                                return TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 24),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () async {
                                    await repository.releaseMilestone(escrow.id, m.id);
                                    final updated = await repository.getEscrowDetails(escrow.id);
                                    setState(() {
                                      _selectedEscrow = updated;
                                    });
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Pushed milestone release confirmation request to customer.')),
                                      );
                                    }
                                  },
                                  child: const Text('Request Release', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                                );
                              }
                            ),
                        ]
                        else
                          Text(m.status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isReleased ? AppColors.tertiary : AppColors.outline)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // Dispute Monitoring Section (Visible when status is 'Disputed')
        if (escrow.status == 'Disputed') _buildDisputeArbitrationPanel(repository),

        // General Refund Action
        if (escrow.status != 'Released' && escrow.status != 'Completed' && escrow.status != 'Refunded') ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => _confirmRefundEscrow(repository, escrow),
            icon: const Icon(Icons.undo),
            label: const Text('Initiate Full Refund Release', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  Widget _buildDisputeArbitrationPanel(ZeroPayRepository repository) {
    return FutureBuilder<DisputeCase>(
      future: repository.getDisputeCase('DS-9281'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }
        final dispute = snapshot.data!;
        final votingComplete = dispute.jurors.where((j) => j.hasVoted).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active Dispute Case & Court Jury Status', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            BentoCard(
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Case ID: ${dispute.caseId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error)),
                      const Text('Under Review', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.error)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(dispute.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Disputed Value: ${dispute.disputedAmount} ${dispute.assetSymbol}', style: const TextStyle(fontSize: 11)),
                      Text('Plaintiff: ${dispute.plaintiffName}', style: const TextStyle(fontSize: 11, color: AppColors.outline)),
                    ],
                  ),
                  const Divider(height: 20),
                  // Jury Consensual leaning
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Jury Leaning Leaning', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      Text('${dispute.consensusLeaningCustomer.toInt()}% Customer', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: dispute.consensusLeaningCustomer / 100,
                      backgroundColor: Colors.amber.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Jurors votes
                  Text('Jury Vote Verification ($votingComplete / ${dispute.jurors.length} Voted)', style: const TextStyle(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: dispute.jurors.map((j) {
                      return Chip(
                        avatar: Icon(j.hasVoted ? Icons.check_circle : Icons.radio_button_unchecked, size: 10, color: j.hasVoted ? AppColors.tertiary : AppColors.outline),
                        label: Text(j.name, style: const TextStyle(fontSize: 9)),
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.surfaceContainerLow,
                      );
                    }).toList(),
                  ),
                  const Divider(height: 24),
                  // Submit evidence form
                  const Text('Submit Counter-Evidence', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _evidenceController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Enter transaction hashes, shipping receipts, or client communications...',
                      hintStyle: const TextStyle(fontSize: 11),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.error, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                if (_evidenceController.text.isEmpty) return;
                                setState(() => _isSubmitting = true);
                                await repository.submitEvidence(dispute.caseId, _evidenceController.text);
                                _evidenceController.clear();
                                setState(() => _isSubmitting = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Evidence encrypted and logged to secure contract state.')),
                                  );
                                }
                              },
                        icon: _isSubmitting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.upload_file, size: 14),
                        label: const Text('Publish Evidence', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = AppColors.primary;
    if (status == 'Released' || status == 'Completed') {
      color = AppColors.tertiary;
    } else if (status == 'Disputed') {
      color = AppColors.error;
    } else if (status == 'Pending') {
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  void _confirmRefundEscrow(ZeroPayRepository repository, Escrow escrow) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Escrow Refund', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to refund the remaining locked collateral in contract ${escrow.id} back to customer ${escrow.counterpartyName}? This action is immediate and irrevocable on-chain.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.pop(context);
                // Simulate Refund update
                await repository.raiseDispute(escrow.id); // updates mock state to disputed or similar
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Refund transactions generated. Broadcasted to Cardano node.')),
                  );
                }
                setState(() => _selectedEscrow = null);
              },
              child: const Text('Confirm Refund'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMerchantAuditStatusCard(Escrow escrow) {
    if (_isLoadingAudits) {
      return const BentoCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_githubAudits.isEmpty) {
      return BentoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('GitHub Code Audit', style: TextStyle(fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () {
                    context.push('/trust/github-audit?projectPlanId=${escrow.projectPlanId}');
                  },
                  child: const Text('View Dashboard →', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'No audits have been executed yet. Payout release requests are locked until the code repository is connected and audited.',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
        ),
      );
    }

    final latestAudit = _githubAudits.first;
    final score = (latestAudit['releaseConfidenceScore'] as num?)?.toDouble() ?? 0.0;
    final status = latestAudit['auditStatus'] as String? ?? 'FAILED';
    final isPassed = status == 'PASSED' && score >= 70.0;

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GitHub Audit: ${isPassed ? "PASSED" : "FAILED"}',
                style: TextStyle(fontWeight: FontWeight.bold, color: isPassed ? AppColors.tertiary : AppColors.error),
              ),
              GestureDetector(
                onTap: () {
                  context.push('/trust/github-audit?auditId=${latestAudit['auditId']}&projectPlanId=${escrow.projectPlanId}');
                },
                child: const Text('View Findings →', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isPassed
                ? 'Your code has passed verification (Release Score: ${score.toInt()}%). You may now request milestone release.'
                : 'Your code does not meet verification thresholds (Release Score: ${score.toInt()}%). Request release is currently locked. Please check the findings and resolve errors.',
            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
