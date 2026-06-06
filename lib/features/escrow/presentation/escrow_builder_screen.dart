import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/data/repository.dart';
import '../../../shared/providers/global_providers.dart';
import '../../merchant/presentation/revenue_analytics_screen.dart';

enum PlannerSubView {
  input,
  blueprint,
  milestones,
  summary,
}

class EscrowBuilderScreen extends ConsumerStatefulWidget {
  const EscrowBuilderScreen({super.key});

  @override
  ConsumerState<EscrowBuilderScreen> createState() => _EscrowBuilderScreenState();
}

class _EscrowBuilderScreenState extends ConsumerState<EscrowBuilderScreen> with TickerProviderStateMixin {
  int _currentStep = 0;
  final _formKey1 = GlobalKey<FormState>();

  // Step 0 AI Planner State
  ProjectPlan? _projectPlan;
  List<ProjectPlan> _planVersions = [];
  bool _isGeneratingPlan = false;
  final _requirementsController = TextEditingController();
  final _budgetController = TextEditingController();
  final Set<int> _expandedMatrixRows = {};
  
  PlannerSubView _plannerSubView = PlannerSubView.input;
  String _selectedCurrency = 'USDC';
  String _selectedComplexity = 'Medium';
  String _projectType = 'Web Application';
  String _additionalContext = '';
  
  // Loading step simulation
  int _loadingStepIndex = 0;
  Timer? _loadingStepTimer;
  
  final List<String> _loadingSteps = [
    'Analyzing requirements...',
    'Generating milestones...',
    'Estimating timelines...',
    'Calculating budget allocation...',
    'Creating audit requirements...',
    'Designing escrow structure...',
    'Finalizing project plan...',
  ];

  // Step 1 Controllers
  final _titleController = TextEditingController();
  final _counterpartyAddressController = TextEditingController();
  final _counterpartyNameController = TextEditingController();
  String _selectedAsset = 'USDC';
  String _selectedChain = 'Cardano Mainnet';

  // Step 2 Milestone List
  final List<Milestone> _milestones = [];
  final _milestoneTitleController = TextEditingController();
  final _milestoneDescController = TextEditingController();
  final _milestoneAmountController = TextEditingController();

  // Deployment Overlay State
  bool _isDeploying = false;
  int _deploySubStep = 0;
  Timer? _deployTimer;
  String _simulatedTxHash = '';
  String _simulatedContractAddr = '';

  final List<String> _deployLogs = [
    'Compiling Plutus / Solidity escrow script...',
    'Generating secure multi-sig ledger address...',
    'Broadcasting contract bytecode to Cardano network...',
    'Verifying escrow contract execution logic...',
    'Transmitting USDC/ADA funding lock transaction...',
    'Awaiting confirmation from ledger block validator...',
    'Block #1938522 verified. Escrow deployed and locked!',
  ];

  @override
  void initState() {
    super.initState();
    _requirementsController.text = 'Build a fintech dashboard with analytics, authentication, role-based access, notifications, and deployment.';
    _budgetController.text = '5000';

    // Default mock data to speed up entry for hackathon review
    _titleController.text = 'Core UI Frontend Implementation';
    _counterpartyAddressController.text = 'addr_test1qru2a8b7c93...5544';
    _counterpartyNameController.text = 'Lumina Web Devs';
    
    // Add default milestones
    _milestones.addAll([
      Milestone(id: 'ms_b1', title: 'Figma Design Signoff', description: 'Complete UI UX blueprints.', amount: 500.0, status: 'Pending'),
      Milestone(id: 'ms_b2', title: 'Front-end Shell Dev', description: 'Complete Flutter widget structures.', amount: 1000.0, status: 'Pending'),
    ]);
  }

  @override
  void dispose() {
    _requirementsController.dispose();
    _budgetController.dispose();
    _titleController.dispose();
    _counterpartyAddressController.dispose();
    _counterpartyNameController.dispose();
    _milestoneTitleController.dispose();
    _milestoneDescController.dispose();
    _milestoneAmountController.dispose();
    _deployTimer?.cancel();
    _loadingStepTimer?.cancel();
    super.dispose();
  }

  double get _totalEscrowValue => _milestones.fold(0.0, (sum, m) => sum + m.amount);

  void _addMilestone() {
    if (_milestoneTitleController.text.isEmpty || _milestoneAmountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title and amount for the milestone.')),
      );
      return;
    }
    final amount = double.tryParse(_milestoneAmountController.text) ?? 0.0;
    if (amount <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid milestone amount.')),
      );
      return;
    }

    setState(() {
      _milestones.add(
        Milestone(
          id: 'ms_custom_${DateTime.now().millisecondsSinceEpoch}',
          title: _milestoneTitleController.text,
          description: _milestoneDescController.text,
          amount: amount,
          status: 'Pending',
        ),
      );
      _milestoneTitleController.clear();
      _milestoneDescController.clear();
      _milestoneAmountController.clear();
    });
    Navigator.of(context).pop(); // close bottom sheet
  }

  void _showAddMilestoneSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: GlassPanel(
          radius: 24,
          backgroundColor: AppColors.surfaceContainerLowest.withOpacity(0.98),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Add Project Milestone',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _milestoneTitleController,
                  decoration: InputDecoration(
                    labelText: 'Milestone Title',
                    hintText: 'e.g., Database Schema & API Setup',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _milestoneDescController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Deliverables expected for verification',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _milestoneAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Payout Amount',
                    hintText: '0.00',
                    suffixText: _selectedAsset,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: _addMilestone,
                      child: const Text('Add Milestone'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startDeploymentSequence() async {
    setState(() {
      _isDeploying = true;
      _deploySubStep = 0;
      _simulatedTxHash = '';
      _simulatedContractAddr = '';
    });

    final netName = _selectedChain.toLowerCase().contains('cardano') ? 'cardano' : 'base';

    try {
      // Step 1: Compiling Plutus / Solidity escrow script... (log 0)
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _deploySubStep = 1); // 'Generating secure multi-sig ledger address...'

      // Step 2: Generating secure multi-sig ledger address... (log 1)
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _deploySubStep = 2); // 'Broadcasting contract bytecode to Cardano network...'

      // If we have a project plan, we first need to approve it on the backend.
      String invoiceId = 'ZP-${DateTime.now().millisecondsSinceEpoch % 10000}';
      String paymentAddress = _counterpartyAddressController.text.isNotEmpty 
          ? _counterpartyAddressController.text 
          : 'addr_test1qru2a8b7c93...5544';
      DateTime createdAt = DateTime.now();
      String? projectPlanId;
      String escrowTitle = _titleController.text.isNotEmpty 
          ? _titleController.text 
          : 'Freelance Design & Development';
      String counterpartyName = _counterpartyNameController.text.isNotEmpty 
          ? _counterpartyNameController.text 
          : 'BlockMasons Inc.';

      if (_projectPlan != null) {
        // We call approveProjectPlan on the backend
        final res = await ref.read(zeroPayRepositoryProvider)
            .approveProjectPlan(_projectPlan!.planId, network: netName);
        
        final invoice = res['invoice'] as Map<String, dynamic>;
        final approvedPlan = res['projectPlan'] as ProjectPlan;

        invoiceId = invoice['invoiceId'] as String;
        paymentAddress = invoice['paymentAddress'] as String? ?? paymentAddress;
        createdAt = approvedPlan.createdAt;
        projectPlanId = approvedPlan.planId;
        escrowTitle = approvedPlan.projectSummary;
        counterpartyName = _counterpartyNameController.text.isNotEmpty 
            ? _counterpartyNameController.text 
            : 'Client';
      }

      if (!mounted) return;
      setState(() {
        _simulatedContractAddr = paymentAddress;
        _deploySubStep = 3; // 'Verifying escrow contract execution logic...'
      });

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _deploySubStep = 4); // 'Transmitting USDC/ADA funding lock transaction...'

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _deploySubStep = 5); // 'Awaiting confirmation from ledger block validator...'

      final newEscrow = Escrow(
        id: invoiceId,
        title: escrowTitle,
        counterpartyAddress: _counterpartyAddressController.text.isNotEmpty 
            ? _counterpartyAddressController.text 
            : 'addr_test1qru2a8b7c93...5544',
        counterpartyName: counterpartyName,
        totalValue: _totalEscrowValue,
        assetSymbol: _selectedAsset,
        status: 'Locked',
        contractAddress: paymentAddress,
        chainName: _selectedChain,
        createdAt: createdAt,
        milestones: List<Milestone>.from(_milestones),
        projectPlanId: projectPlanId,
      );

      // Now create the escrow contract (which does building, signing, and submitting the transaction on-chain)
      final txHash = await ref.read(zeroPayRepositoryProvider).createEscrow(newEscrow);

      // If successful, update the simulated fields for the UI success card and set step to 6
      if (!mounted) return;
      setState(() {
        _simulatedTxHash = txHash;
        if (paymentAddress.isEmpty) {
          _simulatedContractAddr = newEscrow.contractAddress;
        }
        _deploySubStep = 6; // 'Block #1938522 verified. Escrow deployed and locked!'
      });

      // Invalidate the providers to trigger updates in other screens
      ref.invalidate(customerEscrowsProvider);
      ref.invalidate(merchantEscrowsProvider);
      ref.invalidate(escrowSummaryProvider);
      ref.invalidate(merchantRevenueAnalyticsProvider);

    } catch (err) {
      debugPrint('[EscrowBuilderScreen] deployment error: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to deploy escrow contract: $err'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() {
          _isDeploying = false;
        });
      }
    }
  }

  Future<void> _generatePlan() async {
    if (_requirementsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter project requirements description.')),
      );
      return;
    }

    final budgetAmt = double.tryParse(_budgetController.text) ?? 5000.0;
    final budgetPaise = (budgetAmt * 100).round();

    setState(() {
      _isGeneratingPlan = true;
      _currentStep = 0;
      _loadingStepIndex = 0;
    });

    _loadingStepTimer?.cancel();
    _loadingStepTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (_loadingStepIndex < _loadingSteps.length - 1) {
        setState(() {
          _loadingStepIndex++;
        });
      }
    });

    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      String finalRequirements = _requirementsController.text;
      if (_additionalContext.trim().isNotEmpty) {
        finalRequirements += '\n\nAdditional Context:\n$_additionalContext';
      }
      final plan = await repo.generateProjectPlan(
        requirements: finalRequirements,
        totalAmountPaise: budgetPaise,
      );
      
      final versions = await repo.getProjectPlanVersions(plan.planId);

      _loadingStepTimer?.cancel();
      setState(() {
        _projectPlan = plan;
        _planVersions = versions;
        _isGeneratingPlan = false;
        _plannerSubView = PlannerSubView.blueprint;
      });
    } catch (e) {
      _loadingStepTimer?.cancel();
      setState(() {
        _isGeneratingPlan = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate project plan: $e')),
      );
    }
  }

  Future<void> _regeneratePlan() async {
    final budgetAmt = double.tryParse(_budgetController.text) ?? 5000.0;
    final budgetPaise = (budgetAmt * 100).round();

    setState(() {
      _isGeneratingPlan = true;
      _loadingStepIndex = 0;
    });

    _loadingStepTimer?.cancel();
    _loadingStepTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (_loadingStepIndex < _loadingSteps.length - 1) {
        setState(() {
          _loadingStepIndex++;
        });
      }
    });

    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      String finalRequirements = _requirementsController.text;
      if (_additionalContext.trim().isNotEmpty) {
        finalRequirements += '\n\nAdditional Context:\n$_additionalContext';
      }
      final newPlan = await repo.regenerateProjectPlan(
        _projectPlan?.planId ?? '',
        requirements: finalRequirements,
        totalAmountPaise: budgetPaise,
      );

      final versions = await repo.getProjectPlanVersions(newPlan.planId);

      _loadingStepTimer?.cancel();
      setState(() {
        _projectPlan = newPlan;
        _planVersions = versions;
        _isGeneratingPlan = false;
        _plannerSubView = PlannerSubView.blueprint;
      });
    } catch (e) {
      _loadingStepTimer?.cancel();
      setState(() {
        _isGeneratingPlan = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to regenerate plan: $e')),
      );
    }
  }

  Future<void> _loadPlanVersion(int version) async {
    if (_projectPlan == null) return;
    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      final plan = await repo.getProjectPlanVersion(_projectPlan!.planId, version);
      setState(() {
        _projectPlan = plan;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load version: $e')),
      );
    }
  }

  void _approveAndContinuePlan() {
    if (_projectPlan == null) return;
    setState(() {
      _titleController.text = _projectPlan!.projectSummary;
      _milestones.clear();
      _milestones.addAll(_projectPlan!.milestones.map((m) => Milestone(
        id: m.milestoneId,
        title: m.title,
        description: m.description,
        amount: m.amountPaise / 100.0,
        status: 'Pending',
      )));
      _currentStep = 1;
    });
  }

  void _showEditMilestonePlanSheet(int index) {
    final milestone = _projectPlan!.milestones[index];
    final titleEditController = TextEditingController(text: milestone.title);
    final descEditController = TextEditingController(text: milestone.description);
    final amountEditController = TextEditingController(text: (milestone.amountPaise / 100).toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: GlassPanel(
          radius: 24,
          backgroundColor: AppColors.surfaceContainerLowest.withOpacity(0.98),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Edit Plan Milestone',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleEditController,
                  decoration: InputDecoration(
                    labelText: 'Milestone Title',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descEditController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountEditController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () {
                        final amt = double.tryParse(amountEditController.text) ?? 0.0;
                        final newMilestones = List<ProjectPlanMilestone>.from(_projectPlan!.milestones);
                        newMilestones[index] = ProjectPlanMilestone(
                          milestoneId: milestone.milestoneId,
                          title: titleEditController.text,
                          description: descEditController.text,
                          amountPaise: (amt * 100).round(),
                          status: milestone.status,
                          githubAuditRequirements: milestone.githubAuditRequirements,
                        );

                        final updatedPlanData = {
                          'milestones': newMilestones.map((e) => e.toJson()).toList(),
                        };

                        ref.read(zeroPayRepositoryProvider)
                            .updateProjectPlan(_projectPlan!.planId, updatedPlanData)
                            .then((updatedPlan) {
                          setState(() {
                            _projectPlan = updatedPlan;
                            final idx = _planVersions.indexWhere((element) => element.version == updatedPlan.version);
                            if (idx != -1) {
                              _planVersions[idx] = updatedPlan;
                            }
                          });
                          Navigator.of(context).pop();
                        });
                      },
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Escrow Agreement Builder',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildStepHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildCurrentStepContent(),
                  ),
                ),
                _buildBottomActionBar(),
              ],
            ),
          ),
          if (_isDeploying) _buildDeploymentOverlay(),
        ],
      ),
    );
  }

  Widget _buildStepHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      color: AppColors.surfaceContainerLow,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStepIndicator(0, 'AI Plan', Icons.auto_awesome),
          _buildStepLine(0),
          _buildStepIndicator(1, 'Details', Icons.description_outlined),
          _buildStepLine(1),
          _buildStepIndicator(2, 'Milestones', Icons.playlist_add_check_outlined),
          _buildStepLine(2),
          _buildStepIndicator(3, 'Audit & Lock', Icons.lock_outline),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String title, IconData icon) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;
    final color = isActive
        ? AppColors.primary
        : isCompleted
            ? AppColors.tertiary
            : AppColors.outlineVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color.withOpacity(0.08),
          child: Icon(
            isCompleted ? Icons.check : icon,
            size: 14,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? AppColors.onBackground : AppColors.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int afterStep) {
    final isCompleted = _currentStep > afterStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isCompleted ? AppColors.tertiary : AppColors.outlineVariant.withOpacity(0.3),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep0Planner();
      case 1:
        return _buildStep1Details();
      case 2:
        return _buildStep2Milestones();
      case 3:
        return _buildStep3Review();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep0Planner() {
    if (_isGeneratingPlan) {
      return _buildPlanGenerationLoading();
    }

    if (_projectPlan == null) {
      return _buildStep0InputView();
    }

    switch (_plannerSubView) {
      case PlannerSubView.input:
        return _buildStep0InputView();
      case PlannerSubView.blueprint:
        return _buildBlueprintView();
      case PlannerSubView.milestones:
        return _buildMilestonesTasksView();
      case PlannerSubView.summary:
        return _buildPlanSummaryView();
    }
  }

  Widget _buildPlanGenerationLoading() {
    final currentStep = _loadingSteps[_loadingStepIndex];
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80.0, horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const Icon(Icons.auto_awesome, color: AppColors.primary, size: 28),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              '✨ Lumina AI is Architecting Your Plan...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Container(
                key: ValueKey<int>(_loadingStepIndex),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                child: Text(
                  currentStep,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 40),
            const LoadingSkeleton(height: 54, radius: 12),
            const SizedBox(height: 12),
            const LoadingSkeleton(height: 80, radius: 12),
            const SizedBox(height: 12),
            const LoadingSkeleton(height: 80, radius: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildStep0InputView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              '✨',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(width: 8),
            Text(
              'Lumina AI Project Planner',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Describe your project in plain English and let Lumina generate scope, milestones, risks, timelines, budget allocation, GitHub audit requirements and escrow structure.',
          style: TextStyle(color: AppColors.outline, fontSize: 13, height: 1.3),
        ),
        const SizedBox(height: 20),

        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Describe Your Project',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    icon: const Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                    label: const Text('Example', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      setState(() {
                        _requirementsController.text =
                            'I want to build a decentralized freelance platform where clients can post jobs, hire freelancers, make escrow payments using crypto, track progress and release payments securely.';
                        _budgetController.text = '15000';
                        _selectedComplexity = 'High';
                        _projectType = 'Web Application';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _requirementsController,
                maxLines: 5,
                maxLength: 3000,
                decoration: InputDecoration(
                  hintText: 'Describe your idea, target audience, key features...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  counterStyle: const TextStyle(fontSize: 10, color: AppColors.outline),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPromptChip('Build SaaS Dashboard', 'Create a modern B2B SaaS dashboard with user management, subscription metrics, and Stripe integration.', '8000', 'Medium'),
                    const SizedBox(width: 8),
                    _buildPromptChip('Create Fintech App', 'Implement a multi-currency digital wallet app with instant Cardano peer-to-peer transfers and transaction audits.', '20000', 'High'),
                    const SizedBox(width: 8),
                    _buildPromptChip('Build AI Tutor', 'Generate a web portal featuring ChatGPT API study guides, quiz generation, progress metrics, and calendar scheduling.', '6000', 'Medium'),
                    const SizedBox(width: 8),
                    _buildPromptChip('E-Commerce Shop', 'Create a fast storefront featuring product collections, shopping cart, escrow merchant payouts, and review scores.', '12000', 'High'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Target Budget',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 90,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCurrency,
                        items: const [
                          DropdownMenuItem(value: 'USDC', child: Text('USDC', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'ADA', child: Text('ADA', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'INR', child: Text('INR', style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCurrency = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter amount',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLowest,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complexity Preference',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildComplexityButton('Low'),
                  const SizedBox(width: 8),
                  _buildComplexityButton('Medium'),
                  const SizedBox(width: 8),
                  _buildComplexityButton('High'),
                  const SizedBox(width: 8),
                  _buildComplexityButton('Enterprise'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Project Type',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _projectType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                style: const TextStyle(fontSize: 13, color: AppColors.onSurface),
                items: const [
                  DropdownMenuItem(value: 'Web Application', child: Text('Web Application')),
                  DropdownMenuItem(value: 'Mobile Application', child: Text('Mobile Application')),
                  DropdownMenuItem(value: 'Smart Contract / DApp', child: Text('Smart Contract / DApp')),
                  DropdownMenuItem(value: 'AI / LLM Integration', child: Text('AI / LLM Integration')),
                  DropdownMenuItem(value: 'E-Commerce Platform', child: Text('E-Commerce Platform')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _projectType = val);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Additional Context (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (val) => _additionalContext = val,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Any specific tech stack preferences, platform requirements, constraints...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Lumina Core AI Capabilities',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.outline),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _buildCapabilityCard(Icons.schedule, 'Timeline Planning', 'Generates optimistic, realistic, conservative timelines.'),
            _buildCapabilityCard(Icons.warning_amber_outlined, 'Risk Analysis', 'Computes technical, business, and timeline risks.'),
            _buildCapabilityCard(Icons.checklist_rtl, 'Milestone Builder', 'Drafts deliverables and allocates milestone budgets.'),
            _buildCapabilityCard(Icons.lock_person_outlined, 'Escrow Structuring', 'Calculates locked collateral and payout schedules.'),
            _buildCapabilityCard(Icons.code, 'GitHub MCP Auditing', 'Maps code file targets and test criteria for verification.'),
            _buildCapabilityCard(Icons.verified_user_outlined, 'Trust Validation', 'Prevents release disputes by forcing code checks.'),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBlueprintView() {
    final plan = _projectPlan!;
    final confidence = plan.planningConfidence.toDouble();
    final budgetStr = '$_selectedCurrency ${(plan.milestones.fold(0, (sum, m) => sum + m.amountPaise) / 100).toStringAsFixed(0)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BentoCard(
          color: AppColors.primary.withValues(alpha: 0.04),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('✨ AI Generated Blueprint', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Version ${plan.version} • ${plan.createdAt.day}/${plan.createdAt.month}/${plan.createdAt.year}',
                          style: const TextStyle(fontSize: 10, color: AppColors.outline),
                        ),
                        if (_planVersions.length > 1) ...[
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: plan.version,
                            isDense: true,
                            underline: const SizedBox(),
                            items: _planVersions
                                .map((v) => DropdownMenuItem<int>(
                                      value: v.version,
                                      child: Text(
                                        'v${v.version}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                _loadPlanVersion(val);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        BentoCard(
          child: Row(
            children: [
              ReleaseConfidenceGauge(score: confidence, size: 80),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lumina Planning Score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text(
                      'AI confidence based on semantic clarity, dependency mapping, and historical code templates.',
                      style: TextStyle(fontSize: 11, color: AppColors.outline, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('Project Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.outline)),
        const SizedBox(height: 8),
        BentoCard(
          child: Column(
            children: [
              Row(
                children: [
                  _buildOverviewItem(Icons.category_outlined, 'Project Type', _projectType),
                  const SizedBox(width: 8),
                  _buildOverviewItem(Icons.psychology_outlined, 'Complexity', _selectedComplexity),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildOverviewItem(Icons.schedule, 'Est. Duration', '${plan.realisticDays} Days'),
                  const SizedBox(width: 8),
                  _buildOverviewItem(Icons.account_balance_wallet_outlined, 'Est. Budget', budgetStr),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('Recommended Tech Stack', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.outline)),
        const SizedBox(height: 8),
        BentoCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStackBadge('Frontend', 'Flutter / Next.js'),
              _buildStackBadge('Backend', 'Node.js / Express'),
              _buildStackBadge('Database', 'MongoDB / PostgreSQL'),
              _buildStackBadge('Smart Contract', 'Solidity / Plutus'),
              _buildStackBadge('Hosting', 'Vercel / AWS'),
              _buildStackBadge('Audit Gate', 'GitHub MCP Agent'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('Timeline Projection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.outline)),
        const SizedBox(height: 8),
        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVisualTimelineBar('Optimistic', plan.optimisticDays, Colors.green, maxDays: plan.conservativeDays),
              const Divider(height: 20),
              _buildVisualTimelineBar('Realistic', plan.realisticDays, AppColors.primary, maxDays: plan.conservativeDays),
              const Divider(height: 20),
              _buildVisualTimelineBar('Conservative', plan.conservativeDays, Colors.orange, maxDays: plan.conservativeDays),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  plan.timelineSummary,
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.outline),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.menu_book, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Project Scope & deliverables', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const Divider(height: 20),
              Text(
                plan.scope,
                style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('Risk Assessment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.outline)),
        const SizedBox(height: 8),
        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Complexity Score:', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                  Text(_selectedComplexity, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Identified Risk Factors:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange)),
              const SizedBox(height: 6),
              if (plan.riskFactors.isNotEmpty)
                ...plan.riskFactors.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      Expanded(child: Text(r, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant))),
                    ],
                  ),
                ))
              else
                const Text('No significant risks identified.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        BentoCard(
          color: Colors.blue.withValues(alpha: 0.03),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.lightbulb_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Text('AI Architectural Recommendations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                ],
              ),
              const SizedBox(height: 10),
              _buildRecRow('Architecture', 'Layered repository pattern with centralized Riverpod providers.'),
              _buildRecRow('Deployment', 'Serverless container endpoints on Google Cloud Run with Redis caching.'),
              _buildRecRow('Audit Plan', 'Verify contract locking state and multi-sig releases via GitHub MCP auditor.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMilestonesTasksView() {
    final plan = _projectPlan!;
    final totalMilestones = plan.milestones.length;
    final totalTasks = plan.tasks.length;
    final budgetStr = '$_selectedCurrency ${(plan.milestones.fold(0, (sum, m) => sum + m.amountPaise) / 100).toStringAsFixed(0)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Project Progress (AI Breakdown)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text('$totalMilestones Milestones • $totalTasks Tasks • ${plan.realisticDays} Days', style: const TextStyle(fontSize: 11, color: AppColors.outline)),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: 0.0,
                backgroundColor: AppColors.outlineVariant.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Milestone Allocations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('Total: $budgetStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 10),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: plan.milestones.length,
          itemBuilder: (context, index) {
            final ms = plan.milestones[index];
            final amount = ms.amountPaise / 100.0;
            final isExpanded = _expandedMatrixRows.contains(index);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: BentoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                child: Text('${index + 1}', style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ms.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '$_selectedCurrency ${amount.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                              onPressed: () => _showEditMilestonePlanSheet(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (ms.description.isNotEmpty)
                      Text(ms.description, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                    
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 6),

                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedMatrixRows.remove(index);
                          } else {
                            _expandedMatrixRows.add(index);
                          }
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.checklist, size: 14, color: AppColors.outline),
                              SizedBox(width: 6),
                              Text('Deliverables & Audit Info', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.outline)),
                            ],
                          ),
                          Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: AppColors.outline),
                        ],
                      ),
                    ),

                    if (isExpanded) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Acceptance Criteria:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.outline)),
                            const SizedBox(height: 4),
                            Text(ms.description.isNotEmpty ? ms.description : 'Standard criteria validation.', style: const TextStyle(fontSize: 10, height: 1.3)),
                            const SizedBox(height: 10),
                            
                            const Text('GitHub Audit Requirements:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.primary)),
                            const SizedBox(height: 4),
                            if (ms.githubAuditRequirements.requiredFiles.isNotEmpty)
                              _buildAuditReqRow('Files', ms.githubAuditRequirements.requiredFiles.join(', ')),
                            if (ms.githubAuditRequirements.requiredFeatures.isNotEmpty)
                              _buildAuditReqRow('Features', ms.githubAuditRequirements.requiredFeatures.join(', ')),
                            if (ms.githubAuditRequirements.requiredTests.isNotEmpty)
                              _buildAuditReqRow('Tests', ms.githubAuditRequirements.requiredTests.join(', ')),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        const Text('Milestone Tasks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: plan.tasks.length,
          itemBuilder: (context, index) {
            final task = plan.tasks[index];
            final priorityColor = task.priority.toLowerCase() == 'high'
                ? Colors.red
                : task.priority.toLowerCase() == 'medium'
                    ? Colors.orange
                    : Colors.blue;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: BentoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            task.priority.toUpperCase(),
                            style: TextStyle(color: priorityColor, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(task.description, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 12, color: AppColors.outline),
                        const SizedBox(width: 4),
                        Text('Estimate: ${task.estimatedHours} hrs', style: const TextStyle(fontSize: 10, color: AppColors.outline)),
                        const Spacer(),
                        const Icon(Icons.link, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        const Text('Traced to Requirements', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPlanSummaryView() {
    final plan = _projectPlan!;
    final totalMilestones = plan.milestones.length;
    final totalTasks = plan.tasks.length;
    final budgetStr = '$_selectedCurrency ${(plan.milestones.fold(0, (sum, m) => sum + m.amountPaise) / 100).toStringAsFixed(0)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BentoCard(
          color: AppColors.tertiary.withValues(alpha: 0.04),
          border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.2)),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.tertiary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Project Plan Generated!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Your AI project plan is ready.',
                  style: TextStyle(color: AppColors.outline, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('Plan Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.outline)),
        const SizedBox(height: 8),
        BentoCard(
          child: Column(
            children: [
              _buildSummaryRow('Project Name', plan.projectSummary),
              const Divider(height: 12),
              _buildSummaryRow('Project Type', _projectType),
              const Divider(height: 12),
              _buildSummaryRow('Complexity', _selectedComplexity),
              const Divider(height: 12),
              _buildSummaryRow('Estimated Duration', '${plan.realisticDays} Days'),
              const Divider(height: 12),
              _buildSummaryRow('Estimated Budget', budgetStr),
              const Divider(height: 12),
              _buildSummaryRow('Total Milestones', '$totalMilestones'),
              const Divider(height: 12),
              _buildSummaryRow('Total Tasks', '$totalTasks'),
              const Divider(height: 12),
              _buildSummaryRow('Generated On', '20 May 2025, 11:45 AM'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('Escrow Recommendation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.outline)),
        const SizedBox(height: 8),
        BentoCard(
          color: AppColors.primary.withValues(alpha: 0.03),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_person_outlined, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Milestone Escrow',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('RECOMMENDED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Funds are divided across distinct milestones. Releases are triggered automatically upon successful GitHub MCP audit verification.',
                      style: TextStyle(fontSize: 11, color: AppColors.outline, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('GitHub Audit Security Layer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.outline)),
        const SizedBox(height: 8),
        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAuditLayerItem('Repository Required', 'Yes (Linked to contract state)'),
              const Divider(height: 12),
              _buildAuditLayerItem('Audit Requirements', 'Automated code deliverables verification'),
              const Divider(height: 12),
              _buildAuditLayerItem('Code Review Requirements', 'PR approval and branch check enforcement'),
              const Divider(height: 12),
              _buildAuditLayerItem('Release Requirements', 'Release Confidence Score >= 70%'),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPromptChip(String title, String details, String budget, String complexity) {
    return ActionChip(
      backgroundColor: AppColors.surfaceContainerLowest,
      side: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      label: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
      onPressed: () {
        setState(() {
          _requirementsController.text = details;
          _budgetController.text = budget;
          _selectedComplexity = complexity;
        });
      },
    );
  }

  Widget _buildComplexityButton(String level) {
    final isSelected = _selectedComplexity == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedComplexity = level),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surfaceContainerLowest,
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            level,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.primary : AppColors.outline,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCapabilityCard(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 9, color: AppColors.outline, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewItem(IconData icon, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppColors.outline),
                const SizedBox(width: 4),
                Text(title, style: const TextStyle(fontSize: 10, color: AppColors.outline)),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _buildStackBadge(String key, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$key: ', style: const TextStyle(fontSize: 10, color: AppColors.outline)),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildVisualTimelineBar(String label, int days, Color color, {required int maxDays}) {
    final ratio = days / maxDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            Text('$days Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.outlineVariant.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                flex: (ratio * 100).round(),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Expanded(
                flex: ((1 - ratio) * 100).round(),
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecRow(String category, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$category:',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.outline)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLayerItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 14, color: AppColors.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 10, color: AppColors.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditReqRow(String category, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '$category:',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.outline),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Details() {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Trustless Escrow Terms',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lock agreement scope, milestone breakdowns, and collateral asset requirements.',
            style: TextStyle(color: AppColors.outline, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Title
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Contract / Agreement Title',
              hintText: 'e.g., Freelance Flutter Development',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (val) => val == null || val.isEmpty ? 'Title is required' : null,
          ),
          const SizedBox(height: 16),

          // Counterparty details
          BentoCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Counterparty Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _counterpartyNameController,
                  decoration: InputDecoration(
                    labelText: 'Counterparty Name',
                    hintText: 'e.g., DevCo Solutions',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _counterpartyAddressController,
                  decoration: InputDecoration(
                    labelText: 'Ledger Settlement Address',
                    hintText: '0x... or addr_...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Settlement address is required' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Network & Assets selection
          BentoCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settlement Network & Locked Collateral',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedChain,
                  decoration: InputDecoration(
                    labelText: 'Blockchain Network',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Cardano Mainnet', child: Text('Cardano Mainnet')),
                    DropdownMenuItem(value: 'Arbitrum One', child: Text('Arbitrum One (USDC Lock)')),
                    DropdownMenuItem(value: 'Ethereum Mainnet', child: Text('Ethereum Mainnet')),
                  ],
                  onChanged: (val) => setState(() => _selectedChain = val!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedAsset,
                  decoration: InputDecoration(
                    labelText: 'Collateral Asset',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'USDC', child: Text('USD Coin (USDC)')),
                    DropdownMenuItem(value: 'ADA', child: Text('Cardano (ADA)')),
                    DropdownMenuItem(value: 'ETH', child: Text('Ether (ETH)')),
                  ],
                  onChanged: (val) => setState(() => _selectedAsset = val!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Milestones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Milestone Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                SizedBox(height: 4),
                Text(
                  'Define milestone deliverables and fund allocations.',
                  style: TextStyle(color: AppColors.outline, fontSize: 12),
                ),
              ],
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _showAddMilestoneSheet,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Milestone', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_milestones.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Column(
                children: [
                  Icon(Icons.playlist_add, size: 48, color: AppColors.outlineVariant),
                  const SizedBox(height: 12),
                  const Text('No milestones added yet', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.outline)),
                  const SizedBox(height: 4),
                  const Text('Add at least one milestone to deploy escrow.', style: TextStyle(color: AppColors.outline, fontSize: 11)),
                ],
              ),
            ),
          )
        else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _milestones.length,
            itemBuilder: (context, index) {
              final ms = _milestones[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: BentoCard(
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ms.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            if (ms.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                ms.description,
                                style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${ms.amount.toStringAsFixed(2)} $_selectedAsset',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                            onPressed: () {
                              setState(() {
                                _milestones.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          BentoCard(
            color: AppColors.primary.withOpacity(0.03),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Lock Collateral Required:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                ),
                Text(
                  '${_totalEscrowValue.toStringAsFixed(2)} $_selectedAsset',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildStep3Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lumina Smart Audit & Contract Deployment',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 4),
        const Text(
          'Verify code audits, secure parameters, and initialize network locks.',
          style: TextStyle(color: AppColors.outline, fontSize: 12),
        ),
        const SizedBox(height: 16),

        // AI Audit Status Panel
        BentoCard(
          border: Border.all(color: AppColors.tertiary.withOpacity(0.3)),
          color: AppColors.tertiary.withOpacity(0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.verified_user_outlined, color: AppColors.tertiary, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Lumina Guard Code Audited - 100% Score',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.tertiary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Lumina AI has cross-checked settlement parameters against past verified escrow layouts. Settlement address matches authorized DevCo credentials. No variable logic exploits detected. Automated payout routes validated.',
                style: TextStyle(fontSize: 11, height: 1.3, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Contract details breakdown
        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Escrow Ledger Terms', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Divider(height: 20),
              _buildReviewRow('Title', _titleController.text),
              _buildReviewRow('Counterparty', _counterpartyNameController.text),
              _buildReviewRow('Chain Network', _selectedChain),
              _buildReviewRow('Milestones', '${_milestones.length} milestones defined'),
              _buildReviewRow('Token Lock', '$_totalEscrowValue $_selectedAsset'),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Estimated Gas Fee', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                  Text('~0.12 ADA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Dev Preview bytecode visual spell
        BentoCard(
          color: AppColors.onBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('CONTRACT BYTECODE PREVIEW (PLUTUS V2)', style: TextStyle(fontSize: 9, color: AppColors.outlineVariant, fontFamily: 'monospace')),
                  Icon(Icons.code, size: 12, color: AppColors.outlineVariant),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '4d534720455343524f575f4c4f434b5f494e49545f43415244414e4f5f5632\n'
                '3a09a9d5ee1034cbcb9fb3ddd6bc7e074a8d9a2b37494a8f9c1d0f81d112ba\n'
                'VALIDATOR: \\x46\\x48\\xD4 (EscrowLockVerifier)\n'
                'PARAMS: valHash=${_counterpartyAddressController.text.hashCode}',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontFamily: 'monospace', height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.outline)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    if (_currentStep == 0 && _isGeneratingPlan) {
      return const SizedBox.shrink();
    }

    String nextButtonText = 'Continue';
    if (_currentStep == 0) {
      if (_projectPlan == null) {
        nextButtonText = 'Generate AI Plan';
      } else {
        switch (_plannerSubView) {
          case PlannerSubView.input:
            nextButtonText = 'Generate AI Plan';
            break;
          case PlannerSubView.blueprint:
            nextButtonText = 'Review Milestones';
            break;
          case PlannerSubView.milestones:
            nextButtonText = 'Approve Plan & Continue';
            break;
          case PlannerSubView.summary:
            nextButtonText = 'Create Escrow From Plan';
            break;
        }
      }
    } else if (_currentStep == 2) {
      nextButtonText = 'Continue';
    } else if (_currentStep == 3) {
      nextButtonText = 'Deploy & Lock Collateral';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => setState(() => _currentStep--),
              child: const Text('Back'),
            )
          else if (_projectPlan != null)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() {
                  if (_plannerSubView == PlannerSubView.blueprint) {
                    _projectPlan = null;
                    _plannerSubView = PlannerSubView.input;
                  } else if (_plannerSubView == PlannerSubView.milestones) {
                    _plannerSubView = PlannerSubView.blueprint;
                  } else if (_plannerSubView == PlannerSubView.summary) {
                    _plannerSubView = PlannerSubView.milestones;
                  } else {
                    _projectPlan = null;
                    _plannerSubView = PlannerSubView.input;
                  }
                });
              },
              child: const Text('Back'),
            )
          else
            const SizedBox.shrink(),
          const SizedBox(width: 12),
          if (_currentStep == 0 && _projectPlan != null && _plannerSubView == PlannerSubView.summary)
            Expanded(
              child: Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {
                        _plannerSubView = PlannerSubView.input;
                      });
                    },
                    child: const Text('Edit/Regen'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Simulating PDF Export of Lumina Project Plan...')),
                      );
                    },
                    child: const Text('PDF'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GradientButton(
                      text: 'Create Escrow',
                      onPressed: _approveAndContinuePlan,
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: GradientButton(
                text: nextButtonText,
                onPressed: () {
                  if (_currentStep == 0) {
                    if (_projectPlan == null) {
                      _generatePlan();
                    } else {
                      switch (_plannerSubView) {
                        case PlannerSubView.input:
                          _regeneratePlan();
                          break;
                        case PlannerSubView.blueprint:
                          setState(() {
                            _plannerSubView = PlannerSubView.milestones;
                          });
                          break;
                        case PlannerSubView.milestones:
                          setState(() {
                            _plannerSubView = PlannerSubView.summary;
                          });
                          break;
                        case PlannerSubView.summary:
                          _approveAndContinuePlan();
                          break;
                      }
                    }
                  } else if (_currentStep == 1) {
                    if (_formKey1.currentState!.validate()) {
                      setState(() => _currentStep++);
                    }
                  } else if (_currentStep == 2) {
                    if (_milestones.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please add at least one milestone.')),
                      );
                      return;
                    }
                    setState(() => _currentStep++);
                  } else {
                    _startDeploymentSequence();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeploymentOverlay() {
    final logsToShow = _deployLogs.take(_deploySubStep + 1).toList();
    final isFinished = _deploySubStep == _deployLogs.length - 1;
    final displayContractAddr = _simulatedContractAddr.length > 18
        ? '${_simulatedContractAddr.substring(0, 18)}...'
        : _simulatedContractAddr;
    final displayTxHash = _simulatedTxHash.length > 18
        ? '${_simulatedTxHash.substring(0, 18)}...'
        : _simulatedTxHash;

    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: BentoCard(
            radius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isFinished)
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Colors.white, size: 32),
                  ),
                const SizedBox(height: 20),
                Text(
                  isFinished ? 'Escrow Successfully Locked' : 'Broadcasting Escrow Smart Contract',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  isFinished ? 'Ledger validation broadcast complete.' : 'Waiting for network block confirmation...',
                  style: const TextStyle(color: AppColors.outline, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Terminal sequence logs
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < logsToShow.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                i == _deploySubStep && !isFinished
                                    ? Icons.pending_outlined
                                    : Icons.check_circle_outline,
                                size: 12,
                                color: i == _deploySubStep && !isFinished
                                    ? AppColors.primary
                                    : AppColors.tertiary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  logsToShow[i],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: i == _deploySubStep && !isFinished
                                        ? AppColors.primary
                                        : AppColors.onSurface,
                                    fontWeight: i == _deploySubStep ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                if (isFinished) ...[
                  const SizedBox(height: 20),
                  // Block transaction card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Contract ID', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                            Text(displayContractAddr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tx Hash', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                            Text(displayTxHash, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setState(() {
                              _isDeploying = false;
                              _currentStep = 0;
                            });
                          },
                          child: const Text('Builder Home'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              final role = ref.read(authProvider).currentRole;
                              context.go(role == 'merchant' ? '/merchant/dashboard' : '/customer/home');
                            }
                          },
                          child: const Text('Back to Home'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReleaseConfidenceGauge extends StatelessWidget {
  final double score;
  final double size;

  const ReleaseConfidenceGauge({
    required this.score,
    this.size = 64,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.tertiary;
    if (score < 50) {
      color = AppColors.error;
    } else if (score < 80) {
      color = Colors.orange;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 5,
            backgroundColor: AppColors.outlineVariant.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text(
            '${score.toInt()}%',
            style: TextStyle(
              fontSize: size * 0.26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
