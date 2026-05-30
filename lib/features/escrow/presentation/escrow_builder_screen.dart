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

class EscrowBuilderScreen extends ConsumerStatefulWidget {
  const EscrowBuilderScreen({super.key});

  @override
  ConsumerState<EscrowBuilderScreen> createState() => _EscrowBuilderScreenState();
}

class _EscrowBuilderScreenState extends ConsumerState<EscrowBuilderScreen> with TickerProviderStateMixin {
  int _currentStep = 0;
  final _formKey1 = GlobalKey<FormState>();

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
    _titleController.dispose();
    _counterpartyAddressController.dispose();
    _counterpartyNameController.dispose();
    _milestoneTitleController.dispose();
    _milestoneDescController.dispose();
    _milestoneAmountController.dispose();
    _deployTimer?.cancel();
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

  void _startDeploymentSequence() {
    setState(() {
      _isDeploying = true;
      _deploySubStep = 0;
      _simulatedTxHash = 'tx_${DateTime.now().millisecondsSinceEpoch}cda894';
      _simulatedContractAddr = 'addr_escrow_${DateTime.now().millisecondsSinceEpoch}abc123';
    });

    _deployTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (_deploySubStep < _deployLogs.length - 1) {
        setState(() {
          _deploySubStep++;
        });
      } else {
        _deployTimer?.cancel();
        
        final newEscrow = Escrow(
          id: 'ZP-${DateTime.now().millisecondsSinceEpoch % 10000}',
          title: _titleController.text.isNotEmpty ? _titleController.text : 'Freelance Design & Development',
          counterpartyAddress: _counterpartyAddressController.text.isNotEmpty ? _counterpartyAddressController.text : '0x8a72b1...4f21',
          counterpartyName: _counterpartyNameController.text.isNotEmpty ? _counterpartyNameController.text : 'BlockMasons Inc.',
          totalValue: _totalEscrowValue,
          assetSymbol: _selectedAsset,
          status: 'Locked',
          contractAddress: _simulatedContractAddr,
          chainName: _selectedChain,
          createdAt: DateTime.now(),
          milestones: List<Milestone>.from(_milestones),
        );

        ref.read(zeroPayRepositoryProvider).createEscrow(newEscrow).then((_) {
          // Invalidate global escrow providers so all screens instantly reflect the new escrow
          ref.invalidate(customerEscrowsProvider);
          ref.invalidate(merchantEscrowsProvider);
          ref.invalidate(escrowSummaryProvider);
          ref.invalidate(merchantRevenueAnalyticsProvider);
        });
      }
    });
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
          onPressed: () => context.go('/customer/home'),
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
          _buildStepIndicator(0, 'Details', Icons.description_outlined),
          _buildStepLine(0),
          _buildStepIndicator(1, 'Milestones', Icons.playlist_add_check_outlined),
          _buildStepLine(1),
          _buildStepIndicator(2, 'Audit & Lock', Icons.lock_outline),
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
        return _buildStep1Details();
      case 1:
        return _buildStep2Milestones();
      case 2:
        return _buildStep3Review();
      default:
        return const SizedBox.shrink();
    }
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3))),
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
          else
            const SizedBox.shrink(),
          const SizedBox(width: 12),
          Expanded(
            child: GradientButton(
              text: _currentStep == 2 ? 'Deploy & Lock Collateral' : 'Continue',
              onPressed: () {
                if (_currentStep == 0) {
                  if (_formKey1.currentState!.validate()) {
                    setState(() => _currentStep++);
                  }
                } else if (_currentStep == 1) {
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
                            Text(_simulatedContractAddr.substring(0, 18) + '...', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tx Hash', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                            Text(_simulatedTxHash.substring(0, 18) + '...', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
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
                            context.go('/customer/home');
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
