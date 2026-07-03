import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/data/repository.dart';
import '../../../shared/providers/global_providers.dart';
import '../../trust/presentation/audit_release_gate.dart';

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

  ProjectPlan? _projectPlan;
  final _repoUrlController = TextEditingController();
  final _branchController = TextEditingController(text: 'main');

  @override
  void dispose() {
    _evidenceController.dispose();
    _repoUrlController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  void _selectEscrow(Escrow escrow) async {
    setState(() {
      _selectedEscrow = escrow;
      _githubAudits = [];
      _projectPlan = null;
      _isLoadingAudits = true;
    });
    if (escrow.projectPlanId != null) {
      try {
        final repo = ref.read(zeroPayRepositoryProvider);
        final plan = await repo.getLatestProjectPlan(escrow.projectPlanId!);
        if (plan.repositoryUrl != null) {
          _repoUrlController.text = plan.repositoryUrl!;
          _branchController.text = plan.branch ?? 'main';
        } else {
          _repoUrlController.clear();
          _branchController.text = 'main';
        }
        final audits = await repo.getProjectGitHubAudits(escrow.projectPlanId!);
        setState(() {
          _projectPlan = plan;
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

  Future<void> _connectRepository() async {
    if (_repoUrlController.text.trim().isEmpty) return;
    final escrow = _selectedEscrow;
    if (escrow == null || escrow.projectPlanId == null) return;

    setState(() => _isLoadingAudits = true);
    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      final res = await repo.connectGitHubRepository(
        projectPlanId: escrow.projectPlanId!,
        repositoryUrl: _repoUrlController.text.trim(),
        branch: _branchController.text.trim(),
      );

      if (res['success'] == true) {
        final plan = await repo.getLatestProjectPlan(escrow.projectPlanId!);
        final audits = await repo.getProjectGitHubAudits(escrow.projectPlanId!);
        
        // Invalidate escrows lists to refresh UI immediately
        ref.invalidate(customerEscrowsProvider);
        ref.invalidate(merchantEscrowsProvider);
        
        setState(() {
          _projectPlan = plan;
          _githubAudits = audits;
          _isLoadingAudits = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GitHub repository connected successfully!')),
          );
        }
      } else {
        setState(() => _isLoadingAudits = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? 'Connection failed')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoadingAudits = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _disconnectRepository() async {
    final escrow = _selectedEscrow;
    if (escrow == null || escrow.projectPlanId == null) return;

    setState(() => _isLoadingAudits = true);
    try {
      setState(() {
        if (_projectPlan != null) {
          _projectPlan = ProjectPlan(
            planId: _projectPlan!.planId,
            version: _projectPlan!.version,
            merchantId: _projectPlan!.merchantId,
            customerId: _projectPlan!.customerId,
            invoiceId: _projectPlan!.invoiceId,
            requirements: _projectPlan!.requirements,
            projectSummary: _projectPlan!.projectSummary,
            scope: _projectPlan!.scope,
            milestones: _projectPlan!.milestones,
            tasks: _projectPlan!.tasks,
            requirementsBreakdown: _projectPlan!.requirementsBreakdown,
            requirementTrace: _projectPlan!.requirementTrace,
            optimisticDays: _projectPlan!.optimisticDays,
            realisticDays: _projectPlan!.realisticDays,
            conservativeDays: _projectPlan!.conservativeDays,
            timelineSummary: _projectPlan!.timelineSummary,
            acceptanceCriteria: _projectPlan!.acceptanceCriteria,
            riskFactors: _projectPlan!.riskFactors,
            planningConfidence: _projectPlan!.planningConfidence,
            assumptions: _projectPlan!.assumptions,
            unknowns: _projectPlan!.unknowns,
            budgetAllocation: _projectPlan!.budgetAllocation,
            escrowStructure: _projectPlan!.escrowStructure,
            escrowRationale: _projectPlan!.escrowRationale,
            status: _projectPlan!.status,
            createdAt: _projectPlan!.createdAt,
            updatedAt: DateTime.now(),
            repositoryUrl: null,
            repositoryOwner: null,
            repositoryName: null,
            branch: null,
          );
        }
        _githubAudits = [];
        _repoUrlController.clear();
        _branchController.text = 'main';
        _isLoadingAudits = false;
      });
      
      ref.invalidate(customerEscrowsProvider);
      ref.invalidate(merchantEscrowsProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repository connection removed.')),
        );
      }
    } catch (e) {
      setState(() => _isLoadingAudits = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error disconnecting: $e')),
        );
      }
    }
  }

  Future<void> _triggerMilestoneAudit(String projectPlanId, String milestoneId) async {
    setState(() {
      _isLoadingAudits = true;
    });
    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      final res = await repo.triggerMilestoneAudit(
        projectPlanId: projectPlanId,
        milestoneId: milestoneId,
      );
      if (res['success'] == true) {
        final audits = await repo.getProjectGitHubAudits(projectPlanId);
        final updatedEscrow = await repo.getEscrowDetails(_selectedEscrow!.id);
        setState(() {
          _selectedEscrow = updatedEscrow;
          _githubAudits = audits;
          _isLoadingAudits = false;
        });
        
        // Invalidate escrows lists to refresh UI immediately
        ref.invalidate(merchantEscrowsProvider);
        ref.invalidate(customerEscrowsProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GitHub Audit completed successfully!')),
          );
        }
      } else {
        setState(() => _isLoadingAudits = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? 'Audit failed')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoadingAudits = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error triggering audit: $e')),
        );
      }
    }
  }

  List<ProjectTask> _getTasksForMilestone(String milestoneId) {
    if (_projectPlan == null) return [];
    final taskIds = <String>{};
    for (final trace in _projectPlan!.requirementTrace) {
      if (trace.milestoneIds.contains(milestoneId)) {
        taskIds.addAll(trace.taskIds);
      }
    }
    for (final breakdown in _projectPlan!.requirementsBreakdown) {
      if (breakdown.linkedMilestones.contains(milestoneId)) {
        taskIds.addAll(breakdown.linkedTasks);
      }
    }
    return _projectPlan!.tasks.where((t) => taskIds.contains(t.taskId)).toList();
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  DateTime _getMilestoneDueDate(Escrow escrow, int milestoneIndex) {
    final totalDays = _projectPlan?.realisticDays ?? 14;
    final milestonesCount = escrow.milestones.length;
    final share = milestonesCount > 0 ? totalDays / milestonesCount : 7;
    final daysOffset = ((milestoneIndex + 1) * share).ceil();
    return escrow.createdAt.add(Duration(days: daysOffset));
  }

  String _formatDate(DateTime date) {
    return '${_monthName(date.month)} ${date.day}, ${date.year}';
  }

  int _getMilestoneCompletionPercentage(Milestone m) {
    if (m.status == 'Released' || m.status == 'Completed') return 100;
    if (m.status == 'In Progress') return 50;
    return 0;
  }

  Widget _buildAuditStatusBadge(String auditStatus, double score) {
    Color color = AppColors.outline;
    String label = 'NOT AUDITED';
    IconData icon = Icons.help_outline;

    if (auditStatus == 'PASSED') {
      color = AppColors.tertiary;
      label = 'PASSED (${score.toInt()}%)';
      icon = Icons.verified;
    } else if (auditStatus == 'FAILED') {
      color = AppColors.error;
      label = 'FAILED (${score.toInt()}%)';
      icon = Icons.gpp_bad;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseRequestActionWithoutPlanner(ZeroPayRepository repository, Escrow escrow, Milestone m) {
    if (_isLoadingAudits) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Row(
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            minimumSize: const Size(0, 28),
            backgroundColor: AppColors.secondary,
          ),
          onPressed: () async {
            final repo = ref.read(zeroPayRepositoryProvider);
            await repo.releaseMilestone(escrow.id, m.id);
            final updated = await repo.getEscrowDetails(escrow.id);
            setState(() {
              _selectedEscrow = updated;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pushed milestone release confirmation request to customer.')),
              );
            }
          },
          icon: const Icon(Icons.send, size: 12, color: Colors.white),
          label: const Text(
            'Request Release',
            style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectWorkspaceCard(Escrow escrow) {
    if (escrow.projectPlanId == null) return const SizedBox();
    
    final isConnected = _projectPlan?.repositoryUrl != null && _projectPlan!.repositoryUrl!.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Project Workspace', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        BentoCard(
          padding: const EdgeInsets.all(16),
          child: isConnected
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.hub_outlined, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _projectPlan!.repositoryName ?? 'Repository Connected',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 10),
                              SizedBox(width: 4),
                              Text(
                                'Connected',
                                style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Owner: ${_projectPlan!.repositoryOwner ?? "N/A"}',
                      style: const TextStyle(fontSize: 12, color: AppColors.outline),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Branch: ${_projectPlan!.branch ?? "main"}',
                      style: const TextStyle(fontSize: 12, color: AppColors.outline),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'URL: ${_projectPlan!.repositoryUrl}',
                      style: const TextStyle(fontSize: 12, color: AppColors.outline),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              context.push('/trust/github-audit?projectPlanId=${escrow.projectPlanId}');
                            },
                            icon: const Icon(Icons.dashboard, size: 16),
                            label: const Text('Open Audit Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _disconnectRepository,
                          icon: const Icon(Icons.link_off, size: 16),
                          label: const Text('Disconnect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connect GitHub Repository',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Link a repository to track code integration, monitor quality metrics, and automate release gate audits.',
                      style: TextStyle(fontSize: 11, color: AppColors.onBackground.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _repoUrlController,
                      onChanged: (val) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'GitHub Repository URL',
                        labelStyle: const TextStyle(fontSize: 11),
                        hintText: 'https://github.com/owner/repo',
                        hintStyle: const TextStyle(fontSize: 11),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.link, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _branchController,
                      decoration: InputDecoration(
                        labelText: 'Branch Name',
                        labelStyle: const TextStyle(fontSize: 11),
                        hintText: 'main',
                        hintStyle: const TextStyle(fontSize: 11),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.merge_type, size: 18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _repoUrlController.text.trim().isEmpty ? null : _connectRepository,
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('Connect Repository', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMilestoneAuditActions(Escrow escrow, Milestone m) {
    if (_isLoadingAudits) {
      return const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final milestoneAudits = _githubAudits.where((a) => a['milestoneId'] == m.id).toList();
    final latestAudit = milestoneAudits.isNotEmpty ? milestoneAudits.first : null;
    final score = latestAudit != null ? (latestAudit['releaseConfidenceScore'] as num?)?.toDouble() ?? 0.0 : 0.0;
    final status = latestAudit != null ? latestAudit['auditStatus'] as String? ?? 'FAILED' : 'FAILED';
    final isPassed = latestAudit != null && status == 'PASSED' && score >= 70.0;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              minimumSize: const Size(0, 28),
              backgroundColor: AppColors.primary,
            ),
            onPressed: () => _triggerMilestoneAudit(escrow.projectPlanId!, m.id),
            icon: const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
            label: Text(
              latestAudit == null ? 'Mark Complete / Run Audit' : 'Re-run Audit',
              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          if (latestAudit != null) ...[
            const SizedBox(width: 8),
            if (isPassed)
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  minimumSize: const Size(0, 28),
                  backgroundColor: AppColors.tertiary.withValues(alpha: 0.1),
                ),
                onPressed: () async {
                  final repo = ref.read(zeroPayRepositoryProvider);
                  await repo.releaseMilestone(escrow.id, m.id);
                  final updated = await repo.getEscrowDetails(escrow.id);
                  setState(() {
                    _selectedEscrow = updated;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pushed milestone release confirmation request to customer.')),
                    );
                  }
                },
                icon: const Icon(Icons.send, size: 12, color: AppColors.tertiary),
                label: const Text('Request Release', style: TextStyle(fontSize: 10, color: AppColors.tertiary, fontWeight: FontWeight.bold)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Blocked (${score.toInt()}%)',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.error),
                ),
              ),
          ],
        ],
      ),
    );
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

        // Project Workspace Card
        _buildProjectWorkspaceCard(escrow),

        // GitHub AI Audit Panel
        if (escrow.projectPlanId != null) ...[
          AuditReleaseGate(
            audit: _githubAudits.isNotEmpty ? Map<String, dynamic>.from(_githubAudits.first) : null,
            isLoading: _isLoadingAudits,
            projectPlanId: escrow.projectPlanId,
          ),
          const SizedBox(height: 20),
        ],

        // Milestone Manager Panel
        Text('Milestone Progression Manager', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        BentoCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: List.generate(escrow.milestones.length, (index) {
              final m = escrow.milestones[index];
              final isReleased = m.status == 'Released';
              final isInProgress = m.status == 'In Progress';
              final completionPct = _getMilestoneCompletionPercentage(m);
              final dueDate = _getMilestoneDueDate(escrow, index);
              final tasks = _getTasksForMilestone(m.id);

              // Find audit status
              final milestoneAudits = _githubAudits.where((a) => a['milestoneId'] == m.id).toList();
              final latestAudit = milestoneAudits.isNotEmpty ? milestoneAudits.first : null;
              final score = latestAudit != null ? (latestAudit['releaseConfidenceScore'] as num?)?.toDouble() ?? 0.0 : 0.0;
              final auditStatus = latestAudit != null ? latestAudit['auditStatus'] as String? ?? 'FAILED' : 'NOT_AUDITED';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isReleased
                      ? AppColors.tertiary.withValues(alpha: 0.04)
                      : isInProgress
                          ? AppColors.primary.withValues(alpha: 0.04)
                          : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isReleased
                        ? AppColors.tertiary.withValues(alpha: 0.2)
                        : isInProgress
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Status Icon, Title, Amount
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              if (m.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(m.description, style: const TextStyle(fontSize: 10.5, color: AppColors.outline)),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${m.amount} ${escrow.assetSymbol}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary)),
                            const SizedBox(height: 4),
                            Text(
                              m.status,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isReleased ? AppColors.tertiary : AppColors.outline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Milestone Details: Due Date, Completion Pct, Audit Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Completion %
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Progress', style: TextStyle(fontSize: 9, color: AppColors.outline, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('$completionPct%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        // Due date
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Due Date', style: TextStyle(fontSize: 9, color: AppColors.outline, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(_formatDate(dueDate), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        // Audit status badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Audit Status', style: TextStyle(fontSize: 9, color: AppColors.outline, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            _buildAuditStatusBadge(auditStatus, score),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: completionPct / 100.0,
                        minHeight: 6,
                        backgroundColor: AppColors.outlineVariant.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isReleased ? AppColors.tertiary : AppColors.primary,
                        ),
                      ),
                    ),

                    // Linked Tasks list
                    if (tasks.isNotEmpty) ...[
                      const Divider(height: 24),
                      const Text(
                        'Milestone Tasks & Acceptance Criteria',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onBackground),
                      ),
                      const SizedBox(height: 8),
                      ...tasks.map((task) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isReleased ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                                size: 12,
                                color: isReleased ? AppColors.tertiary : AppColors.outline,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.onBackground.withValues(alpha: 0.9),
                                        decoration: isReleased ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    if (task.description.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        task.description,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: AppColors.outline,
                                          decoration: isReleased ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (task.priority == 'high' ? AppColors.error : Colors.orange).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  task.priority.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: task.priority == 'high' ? AppColors.error : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    // Audit action buttons (Re-run / Mark Complete / Release Request)
                    if (isInProgress && escrow.projectPlanId != null) ...[
                      const Divider(height: 24),
                      _buildMilestoneAuditActions(escrow, m),
                    ] else if (isInProgress && escrow.projectPlanId == null) ...[
                      const Divider(height: 24),
                      _buildReleaseRequestActionWithoutPlanner(repository, escrow, m),
                    ],
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 20),

        // Dispute Monitoring Section (Visible when status is 'Disputed')
        if (escrow.status == 'Disputed') _buildDisputeArbitrationPanel(repository, escrow),

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

  Widget _buildDisputeArbitrationPanel(ZeroPayRepository repository, Escrow escrow) {
    return FutureBuilder<DisputeCase>(
      future: repository.getDisputeCase(escrow.id),
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
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
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
                      backgroundColor: Colors.amber.withValues(alpha: 0.2),
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
                                final messenger = ScaffoldMessenger.of(context);
                                setState(() => _isSubmitting = true);
                                await repository.submitEvidence(dispute.caseId, _evidenceController.text);
                                _evidenceController.clear();
                                setState(() => _isSubmitting = false);
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Evidence encrypted and logged to secure contract state.')),
                                );
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  void _confirmRefundEscrow(ZeroPayRepository repository, Escrow escrow) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Escrow Refund', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to refund the remaining locked collateral in contract ${escrow.id} back to customer ${escrow.counterpartyName}? This action is immediate and irrevocable on-chain.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.pop(dialogContext);
                // Simulate Refund update
                await repository.raiseDispute(escrow.id); // updates mock state to disputed or similar
                messenger.showSnackBar(
                  const SnackBar(content: Text('Refund transactions generated. Broadcasted to Cardano node.')),
                );
                setState(() => _selectedEscrow = null);
              },
              child: const Text('Confirm Refund'),
            ),
          ],
        );
      },
    );
  }

}
