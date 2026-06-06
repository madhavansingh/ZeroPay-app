import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/data/repository.dart';
import '../../../shared/presentation/widgets.dart';

enum AuditWorkspaceView {
  connection,
  dashboard,
  matrix,
  report,
}

class GitHubAuditScreen extends ConsumerStatefulWidget {
  final String? auditId;
  final String? projectPlanId;

  const GitHubAuditScreen({this.auditId, this.projectPlanId, super.key});

  @override
  ConsumerState<GitHubAuditScreen> createState() => _GitHubAuditScreenState();
}

class _GitHubAuditScreenState extends ConsumerState<GitHubAuditScreen> with SingleTickerProviderStateMixin {
  bool _isPageLoading = true;
  bool _isActionLoading = false;
  String? _error;
  
  // Navigation & View State
  AuditWorkspaceView _activeView = AuditWorkspaceView.dashboard;
  String _selectedMilestoneId = 'MS-2'; // Default milestone to inspect
  final Set<int> _expandedMatrixRows = {};
  
  // Data State
  String? _currentAuditId;
  String? _currentProjectPlanId;
  Map<String, dynamic>? _auditData;
  Map<String, dynamic>? _snapshotData;
  List<dynamic> _projectAudits = [];
  
  // Connection Form Controllers
  final _repoUrlController = TextEditingController();
  final _branchController = TextEditingController(text: 'main');
  
  // Rework Form Controller
  final _feedbackController = TextEditingController();

  // Selected horizontal tab inside Trace Matrix (0 = Matrix View, 1 = Commits, 2 = PRs, 3 = Files)
  int _activeMatrixTab = 0;

  @override
  void initState() {
    super.initState();
    _currentAuditId = widget.auditId;
    _currentProjectPlanId = widget.projectPlanId;
    _loadInitialData();
  }

  @override
  void dispose() {
    _repoUrlController.dispose();
    _branchController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isPageLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      
      // If we have an audit ID, load details directly
      if (_currentAuditId != null) {
        await _fetchAuditDetails(_currentAuditId!);
      }

      // If we have a project plan ID, fetch all audits for timeline/revision context
      if (_currentProjectPlanId != null) {
        final audits = await repo.getProjectGitHubAudits(_currentProjectPlanId!);
        if (!mounted) return;
        setState(() {
          _projectAudits = audits;
        });

        // If we didn't have a specific audit ID, but audits exist, load the latest one
        if (_currentAuditId == null && audits.isNotEmpty) {
          _currentAuditId = audits.first['auditId'] as String?;
          if (_currentAuditId != null) {
            await _fetchAuditDetails(_currentAuditId!);
          }
        }
      }

      // If no repository is linked in the loaded details, auto-route to connection screen
      final hasRepo = _auditData != null || _projectAudits.isNotEmpty;
      if (!hasRepo) {
        _activeView = AuditWorkspaceView.connection;
      } else {
        _activeView = AuditWorkspaceView.dashboard;
      }
      
      if (!mounted) return;
      setState(() {
        _isPageLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isPageLoading = false;
      });
    }
  }

  Future<void> _fetchAuditDetails(String auditId) async {
    final repo = ref.read(zeroPayRepositoryProvider);
    final response = await repo.getGitHubAuditDetails(auditId);
    
    if (!mounted) return;
    if (response['success'] == true && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      setState(() {
        _auditData = Map<String, dynamic>.from(data['audit'] as Map);
        if (data['snapshot'] != null) {
          _snapshotData = Map<String, dynamic>.from(data['snapshot'] as Map);
        } else {
          _snapshotData = null;
        }
        _currentAuditId = auditId;
        _currentProjectPlanId = _auditData?['projectPlanId'] as String?;
      });
    } else {
      throw Exception(response['error'] ?? 'Failed to load audit details');
    }
  }

  Future<void> _connectRepository() async {
    if (_repoUrlController.text.trim().isEmpty) return;
    if (_currentProjectPlanId == null) return;

    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      final res = await repo.connectGitHubRepository(
        projectPlanId: _currentProjectPlanId!,
        repositoryUrl: _repoUrlController.text.trim(),
        branch: _branchController.text.trim(),
      );

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GitHub repository connected successfully!')),
        );
        // Trigger first audit automatically
        _triggerNewAudit();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Connection failed')),
        );
        setState(() => _isActionLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _triggerNewAudit() async {
    if (_currentProjectPlanId == null) return;
    
    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      final res = await repo.triggerMilestoneAudit(
        projectPlanId: _currentProjectPlanId!,
        milestoneId: _selectedMilestoneId,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final newAudit = res['data'] as Map<String, dynamic>;
        final newAuditId = newAudit['auditId'] as String;
        
        // Reload all data
        _currentAuditId = newAuditId;
        await _loadInitialData();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GitHub Audit completed successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Audit trigger failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audit failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _reverifyAudit() async {
    if (_currentAuditId == null) return;

    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      final res = await repo.reverifyGitHubAudit(_currentAuditId!);
      if (!mounted) return;
      if (res['success'] == true) {
        final newAudit = res['data'] as Map<String, dynamic>;
        _currentAuditId = newAudit['auditId'] as String;
        await _loadInitialData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Re-verification audit completed!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Re-verification failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _requestFixes() async {
    if (_currentAuditId == null || _feedbackController.text.trim().isEmpty) return;

    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      final res = await repo.requestGitHubFixes(_currentAuditId!, _feedbackController.text.trim());
      if (!mounted) return;
      if (res['success'] == true) {
        _feedbackController.clear();
        Navigator.pop(context); // Close dialog
        await _loadInitialData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted to merchant.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Failed to submit feedback')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _approveRelease() async {
    final escrowId = _auditData?['invoiceId'] as String? ?? _auditData?['escrowId'] as String?;
    final milestoneId = _auditData?['milestoneId'] as String?;
    
    if (escrowId == null || milestoneId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find linked escrow contract details for release')),
      );
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      await repo.releaseMilestone(escrowId, milestoneId);
      
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => SuccessDialog(
          title: 'Milestone Released',
          description: 'Funds have been cryptographically unlocked and transferred based on passed audit verification.',
          onConfirm: () {
            context.pop(); // Pop screen
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Release failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _disconnectRepository() async {
    setState(() => _isActionLoading = true);
    try {
      // In mock/development, simply clear repo variables and switch to connection view
      setState(() {
        _auditData = null;
        _snapshotData = null;
        _projectAudits = [];
        _activeView = AuditWorkspaceView.connection;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Repository connection removed.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  void _handleBackPress() {
    if (_activeView == AuditWorkspaceView.dashboard) {
      context.pop();
    } else {
      final hasRepo = _auditData != null || _projectAudits.isNotEmpty;
      if (hasRepo) {
        setState(() {
          _activeView = AuditWorkspaceView.dashboard;
        });
      } else {
        context.pop();
      }
    }
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Request Rework / Fixes', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _feedbackController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe missing items, bugs, or fixes required...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: _requestFixes,
            child: const Text('Submit Feedback', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Get view title for app bar
  String _getViewTitle() {
    switch (_activeView) {
      case AuditWorkspaceView.connection:
        return 'GitHub Connection';
      case AuditWorkspaceView.dashboard:
        return 'GitHub Audit Dashboard';
      case AuditWorkspaceView.matrix:
        return 'Requirement Trace Matrix';
      case AuditWorkspaceView.report:
        return 'Audit Report';
    }
  }

  // Get top bar actions depending on active view
  List<Widget> _getViewActions() {
    switch (_activeView) {
      case AuditWorkspaceView.connection:
      case AuditWorkspaceView.dashboard:
        return [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppColors.onSurfaceVariant),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Audit workspace connects repo files to Project Plan milestones.')),
              );
            },
          ),
        ];
      case AuditWorkspaceView.matrix:
        return [
          IconButton(
            icon: const Icon(Icons.filter_list, color: AppColors.onSurfaceVariant),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Status filters: All, Passed, Partial, Failed.')),
              );
            },
          ),
        ];
      case AuditWorkspaceView.report:
        return [
          IconButton(
            icon: const Icon(Icons.ios_share, color: AppColors.onSurfaceVariant),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing cryptographic audit report PDF...')),
              );
            },
          ),
        ];
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
            onPressed: () => context.pop(),
          ),
          title: const Text('GitHub Audit Agent'),
        ),
        body: ErrorStateView(
          title: 'Failed to load audit data',
          description: _error!,
          onRetry: _loadInitialData,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: _handleBackPress,
        ),
        title: Text(
          _getViewTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onSurface),
        ),
        actions: _getViewActions(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(color: AppColors.outlineVariant.withOpacity(0.3), height: 1.0),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Render standard ZeroPay branding header row (except on Matrix View)
                if (_activeView != AuditWorkspaceView.matrix) _buildZeroPayBrandingRow(),
                
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildActiveViewBody(),
                  ),
                ),
              ],
            ),
          ),
          if (_isActionLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // Shared ZeroPay Branding Row
  Widget _buildZeroPayBrandingRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.all_inclusive, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text(
                'ZeroPay',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.search, color: AppColors.onSurfaceVariant, size: 20),
              const SizedBox(width: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_outlined, color: AppColors.onSurfaceVariant, size: 20),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.swap_horiz, size: 10, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Buyer',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Premium Bottom Navigation Bar matching mockup
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3), width: 1.0)),
      ),
      child: BottomNavigationBar(
        currentIndex: 1, // Escrow active index
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.outline,
        backgroundColor: AppColors.surfaceContainerLowest,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        onTap: (index) {
          if (index == 0) {
            context.go('/customer/home');
          } else if (index == 1) {
            // Stay/Reset to dashboard
            setState(() {
              final hasRepo = _auditData != null || _projectAudits.isNotEmpty;
              _activeView = hasRepo ? AuditWorkspaceView.dashboard : AuditWorkspaceView.connection;
            });
          } else if (index == 2) {
            context.go('/customer/marketplace');
          } else if (index == 3) {
            context.go('/customer/wallet');
          } else if (index == 4) {
            context.go('/customer/profile');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lock_outlined),
            activeIcon: Icon(Icons.lock, color: AppColors.primary),
            label: 'Escrow',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront, color: AppColors.primary),
            label: 'Marketplace',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet, color: AppColors.primary),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // Switcher of View Bodies
  Widget _buildActiveViewBody() {
    switch (_activeView) {
      case AuditWorkspaceView.connection:
        return _buildConnectionScreen();
      case AuditWorkspaceView.dashboard:
        return _buildDashboardScreen();
      case AuditWorkspaceView.matrix:
        return _buildMatrixScreen();
      case AuditWorkspaceView.report:
        return _buildReportScreen();
    }
  }

  // ============================================================================
  // SCREEN 1: GitHub Repository Connection Screen
  // ============================================================================
  Widget _buildConnectionScreen() {
    final isConnected = _auditData != null || _projectAudits.isNotEmpty;

    if (!isConnected) {
      // Connect Form State
      return SingleChildScrollView(
        key: const ValueKey('connectForm'),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(Icons.link_off_rounded, size: 64, color: AppColors.outline),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'No Repository Linked',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Link a GitHub repository to enable autonomous requirement verification.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.outline, fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),
            BentoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Repository Connection Settings',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _repoUrlController,
                    decoration: InputDecoration(
                      labelText: 'GitHub Repository URL',
                      hintText: 'https://github.com/owner/repo',
                      prefixIcon: const Icon(Icons.code, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _branchController,
                    decoration: InputDecoration(
                      labelText: 'Active Branch',
                      hintText: 'main',
                      prefixIcon: const Icon(Icons.call_split, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: GradientButton(
                      text: 'Connect Repository',
                      onPressed: _connectRepository,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Connected Info View State
    final repoUrl = _auditData?['repositoryUrl'] ?? 'github.com/zeropay/escrow-dapp';
    final repoName = repoUrl.toString().replaceAll('https://github.com/', '').replaceAll('github.com/', '');
    final branchName = _auditData?['branch'] ?? 'main';
    final connectedOn = _auditData?['connectedAt'] ?? '20 May 2025';

    return SingleChildScrollView(
      key: const ValueKey('connectInfo'),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Repository details header card
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.onSurface.withOpacity(0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.code, color: AppColors.onSurface, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repoName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'github.com/$repoName',
                              style: const TextStyle(fontSize: 11, color: AppColors.outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.tertiary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Connected',
                        style: TextStyle(color: AppColors.tertiary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Branch', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                        Text(branchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text('Last Synced', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                        Text('2 mins ago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Repository Details Grid
          const Text('Repository Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.outline)),
          const SizedBox(height: 8),
          BentoCard(
            child: Column(
              children: [
                _buildDetailsRow('Owner', 'zeropay'),
                const Divider(height: 12),
                _buildDetailsRow('Visibility', 'Private', icon: Icons.lock_outline),
                const Divider(height: 12),
                _buildDetailsRow('Default Branch', 'main'),
                const Divider(height: 12),
                _buildDetailsRow('Connected On', connectedOn),
                const Divider(height: 12),
                _buildDetailsRow('Webhook Status', 'Active', success: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Milestone Scope Info Box
          const Text('Milestone Scope', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.outline)),
          const SizedBox(height: 8),
          BentoCard(
            onTap: () {
              setState(() {
                _activeView = AuditWorkspaceView.dashboard;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Milestones Linked: ${_projectAudits.length > 0 ? _projectAudits.length : 3}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Next Audit: Milestone 2 In 1 day',
                      style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Icon(Icons.chevron_right, color: AppColors.outline, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          SizedBox(
            width: double.infinity,
            height: 48,
            child: GradientButton(
              text: 'Sync Repository',
              icon: Icons.sync,
              onPressed: _reverifyAudit,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _disconnectRepository,
              icon: const Icon(Icons.link_off, color: AppColors.error, size: 18),
              label: const Text('Disconnect Repository', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsRow(String label, String value, {IconData? icon, bool success = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.outline)),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.outline),
              const SizedBox(width: 4),
            ],
            if (success) ...[
              const Icon(Icons.check_circle_outline, size: 14, color: AppColors.tertiary),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: success ? AppColors.tertiary : AppColors.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================================
  // SCREEN 2: AI Audit Dashboard Screen
  // ============================================================================
  Widget _buildDashboardScreen() {
    final audit = _auditData;
    if (audit == null) {
      return const Center(child: Text('No repository connected.'));
    }

    final projectName = 'Ai Escrow DApp Development';
    final repoUrl = audit['repositoryUrl'] ?? 'github.com/zeropay/escrow-dapp';
    final repoName = repoUrl.toString().replaceAll('https://github.com/', '').replaceAll('github.com/', '');
    final coverage = (audit['releaseConfidenceScore'] as num?)?.toDouble() ?? 82.0;
    final confidence = (audit['confidenceScore'] as num?)?.toDouble() ?? 84.0;
    final status = audit['auditStatus'] as String? ?? 'PARTIAL';

    return SingleChildScrollView(
      key: const ValueKey('dashboard'),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Plan Card
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Project Plan', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                        const SizedBox(height: 2),
                        Text(projectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.outline, size: 18),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Repository', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                        const SizedBox(height: 2),
                        Text(repoName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.link, size: 18, color: AppColors.primary),
                      onPressed: () {
                        setState(() {
                          _activeView = AuditWorkspaceView.connection;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Overall Audit Health Card
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Overall Audit Health', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Coverage Ring on the left
                    CoverageRing(coverage: coverage, size: 90, strokeWidth: 8),
                    const SizedBox(width: 20),
                    // Status Badge and Audit timestamp on the right
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusBadge(status),
                          const SizedBox(height: 8),
                          const Text('Last Audit', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                          const Text('20 May 2025, 11:45 AM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Confidence Score: ${confidence.toInt()}%', style: const TextStyle(fontSize: 11, color: AppColors.outline)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                
                // Metrics Row - 4 columns
                Row(
                  children: [
                    _buildMiniMetricCard('3', 'Milestones'),
                    const SizedBox(width: 8),
                    _buildMiniMetricCard('2', 'Audits Run'),
                    const SizedBox(width: 8),
                    _buildMiniMetricCard('82%', 'Avg Coverage'),
                    const SizedBox(width: 8),
                    _buildMiniMetricCard('1', 'Issues', alert: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Milestones Overview Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Milestones Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Showing all 3 project plan milestones.')),
                  );
                },
                child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Milestones List
          _buildMilestoneOverviewCard(
            id: 'MS-1',
            title: 'Milestone 1 - Smart Contract Core',
            status: 'PASSED',
            coverage: 96.0,
            date: '20 May 2025',
          ),
          const SizedBox(height: 10),
          _buildMilestoneOverviewCard(
            id: 'MS-2',
            title: 'Milestone 2 - Escrow Logic',
            status: 'PARTIAL',
            coverage: 72.0,
            date: 'Today, 11:45 AM',
            showProgress: true,
          ),
          const SizedBox(height: 10),
          _buildMilestoneOverviewCard(
            id: 'MS-3',
            title: 'Milestone 3 - Frontend Integration',
            status: 'PENDING',
            coverage: 0.0,
            date: 'Not started',
          ),
          const SizedBox(height: 24),

          // Bottom Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: GradientButton(
              text: 'Run New Audit',
              icon: Icons.play_arrow,
              onPressed: _triggerNewAudit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetricCard(String value, String label, {bool alert = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: alert ? AppColors.error : AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: AppColors.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.orange;
    String label = 'PARTIALLY COMPLETED';
    
    if (status == 'PASSED') {
      color = AppColors.tertiary;
      label = 'PASSED';
    } else if (status == 'FAILED') {
      color = AppColors.error;
      label = 'FAILED';
    } else if (status == 'INSUFFICIENT_EVIDENCE') {
      color = Colors.grey;
      label = 'INSUFFICIENT EVIDENCE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildMilestoneOverviewCard({
    required String id,
    required String title,
    required String status,
    required double coverage,
    required String date,
    bool showProgress = false,
  }) {
    Color statusColor = Colors.orange;
    if (status == 'PASSED') statusColor = AppColors.tertiary;
    if (status == 'PENDING') statusColor = Colors.grey;

    return BentoCard(
      onTap: () {
        setState(() {
          _selectedMilestoneId = id;
          _activeView = AuditWorkspaceView.matrix;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Coverage: ${coverage.toInt()}%', style: const TextStyle(fontSize: 11, color: AppColors.outline)),
              Text(date, style: const TextStyle(fontSize: 11, color: AppColors.outline)),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: coverage / 100,
              backgroundColor: AppColors.outlineVariant.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              borderRadius: BorderRadius.circular(4),
              minHeight: 4,
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================================
  // SCREEN 3: Requirement Trace Matrix Screen
  // ============================================================================
  Widget _buildMatrixScreen() {
    final mockMilestone = _getMockMilestoneData(_selectedMilestoneId);
    final matrix = mockMilestone['requirementTraceMatrix'] as List? ?? [];
    final coverage = mockMilestone['coverage'] as double;
    final status = mockMilestone['status'] as String;

    Color statusColor = Colors.orange;
    if (status == 'PASSED') statusColor = AppColors.tertiary;
    if (status == 'PENDING') statusColor = Colors.grey;

    return Column(
      key: const ValueKey('matrix'),
      children: [
        // Milestone Info Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      mockMilestone['milestoneTitle'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${mockMilestone['requirementsVerified']} / ${mockMilestone['totalRequirements']} Requirements Verified',
                      style: const TextStyle(fontSize: 11, color: AppColors.outline),
                    ),
                    Text(
                      '${coverage.toInt()}% Coverage',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: coverage / 100,
                  backgroundColor: AppColors.outlineVariant.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
              ],
            ),
          ),
        ),

        // Horizontal Navigation Tabs (Matrix View, Commits, PRs, Files)
        Container(
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildMatrixTabChip(0, 'Matrix View', Icons.grid_on),
              const SizedBox(width: 8),
              _buildMatrixTabChip(1, 'Commits', Icons.history),
              const SizedBox(width: 8),
              _buildMatrixTabChip(2, 'PRs', Icons.merge_type),
              const SizedBox(width: 8),
              _buildMatrixTabChip(3, 'Files', Icons.insert_drive_file_outlined),
            ],
          ),
        ),

        // Table Content
        Expanded(
          child: _activeMatrixTab == 0
              ? _buildTraceMatrixList(matrix)
              : _buildTabAlternativeDetails(mockMilestone),
        ),

        // Verdict Navigation Console
        _buildMatrixBottomNavigationConsole(),
      ],
    );
  }

  Widget _buildMatrixTabChip(int index, String label, IconData icon) {
    final isSelected = _activeMatrixTab == index;
    return ChoiceChip(
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.outline),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceContainerLowest,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.outline),
      onSelected: (val) {
        if (val) {
          setState(() {
            _activeMatrixTab = index;
          });
        }
      },
    );
  }

  Widget _buildTraceMatrixList(List matrix) {
    if (matrix.isEmpty) {
      return const EmptyStateView(
        icon: Icons.grid_on,
        title: 'Trace Matrix Empty',
        description: 'No requirements mapped yet. Perform an initial audit run.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: matrix.length + 1, // +1 for the Legend at bottom
      itemBuilder: (context, index) {
        if (index == matrix.length) {
          return _buildMatrixLegend();
        }

        final req = matrix[index];
        final id = req['requirementId'] ?? 'REQ-${index + 1}';
        final status = req['status'] as String? ?? 'FAILED';
        final compPercent = (req['completionPercentage'] as num?)?.toDouble() ?? 0.0;
        final isExpanded = _expandedMatrixRows.contains(index);

        Color rowStatusColor = Colors.orange;
        IconData statusIcon = Icons.info_outline;

        if (status == 'PASSED') {
          rowStatusColor = AppColors.tertiary;
          statusIcon = Icons.check_circle_outline;
        } else if (status == 'FAILED') {
          rowStatusColor = AppColors.error;
          statusIcon = Icons.cancel_outlined;
        } else if (status == 'NOT_VERIFIED') {
          rowStatusColor = Colors.grey;
          statusIcon = Icons.remove_circle_outline;
        }

        final evidenceFiles = req['evidenceFiles'] as List? ?? [];
        final evidenceCommits = req['evidenceCommits'] as List? ?? [];
        final evidencePRs = req['evidencePRs'] as List? ?? [];

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isExpanded ? AppColors.primary.withOpacity(0.3) : AppColors.outlineVariant.withOpacity(0.3),
              width: isExpanded ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              ListTile(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedMatrixRows.remove(index);
                    } else {
                      _expandedMatrixRows.add(index);
                    }
                  });
                },
                dense: true,
                leading: CircleAvatar(
                  radius: 12,
                  backgroundColor: rowStatusColor.withOpacity(0.1),
                  child: Icon(statusIcon, color: rowStatusColor, size: 14),
                ),
                title: Text(
                  '[$id] ${req['requirementText']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                subtitle: Text(
                  'Evidence: ${evidenceCommits.length}C / ${evidencePRs.length}PR / ${evidenceFiles.length}F',
                  style: const TextStyle(fontSize: 10, color: AppColors.outline),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${compPercent.toInt()}%',
                      style: TextStyle(fontWeight: FontWeight.bold, color: rowStatusColor, fontSize: 11),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.outline,
                    ),
                  ],
                ),
              ),
              
              // Matrix Row Expansion Animation
              if (isExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Compliance Analysis',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        status == 'PASSED'
                            ? 'The code matches all requirements logic. Smart contract lock values have been verified.'
                            : 'Partial verification score assigned. Recommended to complete the event logging implementation.',
                        style: const TextStyle(fontSize: 11, height: 1.3),
                      ),
                      const SizedBox(height: 10),
                      
                      // Files & commits bullet details
                      if (evidenceFiles.isNotEmpty) ...[
                        const Text('Evidence Files:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                        ...evidenceFiles.map((f) => Text(' • $f', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppColors.outline))),
                        const SizedBox(height: 6),
                      ],
                      if (evidenceCommits.isNotEmpty) ...[
                        const Text('Commit Hashes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                        ...evidenceCommits.map((c) => Text(' • $c', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppColors.outline))),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMatrixLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendChip(AppColors.tertiary, 'Verified'),
          const SizedBox(width: 12),
          _buildLegendChip(Colors.orange, 'Partial'),
          const SizedBox(width: 12),
          _buildLegendChip(AppColors.error, 'Failed'),
          const SizedBox(width: 12),
          _buildLegendChip(Colors.grey, 'Not Verified'),
        ],
      ),
    );
  }

  Widget _buildLegendChip(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10, color: AppColors.outline)),
      ],
    );
  }

  Widget _buildTabAlternativeDetails(Map<String, dynamic> milestone) {
    final matrix = milestone['requirementTraceMatrix'] as List? ?? [];
    
    // Gather all commits / files / PRs from the requirements for secondary tabs
    final List<String> commits = [];
    final List<String> files = [];
    for (var r in matrix) {
      final cList = r['evidenceCommits'] as List? ?? [];
      final fList = r['evidenceFiles'] as List? ?? [];
      for (var c in cList) {
        if (!commits.contains(c)) commits.add(c.toString());
      }
      for (var f in fList) {
        if (!files.contains(f)) files.add(f.toString());
      }
    }

    if (_activeMatrixTab == 1) {
      // Commits Tab
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Verified Commit Snapshots', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (commits.isEmpty)
                  const Text('No verified commits attached.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12))
                else
                  ...commits.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.commit, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(c, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        const Spacer(),
                        const Text('Verified', style: TextStyle(color: AppColors.tertiary, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
              ],
            ),
          )
        ],
      );
    } else if (_activeMatrixTab == 2) {
      // PRs Tab
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Linked Pull Requests', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildPRRow('#10', 'Escrow base layout structure', 'Merged', AppColors.tertiary),
                const Divider(),
                _buildPRRow('#11', 'Add deposit fund locking tests', 'Merged', AppColors.tertiary),
                const Divider(),
                _buildPRRow('#12', 'Dispute handling flow implementation', 'Under Review', Colors.orange),
              ],
            ),
          )
        ],
      );
    } else {
      // Files Tab
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Audited Repository Files', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (files.isEmpty)
                  const Text('No files tracked.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12))
                else
                  ...files.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file, size: 14, color: AppColors.outline),
                        const SizedBox(width: 8),
                        Text(f, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                      ],
                    ),
                  )),
              ],
            ),
          )
        ],
      );
    }
  }

  Widget _buildPRRow(String prNum, String title, String status, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prNum, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 8),
          Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildMatrixBottomNavigationConsole() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            setState(() {
              _activeView = AuditWorkspaceView.report;
            });
          },
          icon: const Icon(Icons.description, size: 18),
          label: const Text('View Detailed Verdict Report', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ============================================================================
  // SCREEN 4: Audit Report & Escrow Gate Screen
  // ============================================================================
  Widget _buildReportScreen() {
    final mockMilestone = _getMockMilestoneData(_selectedMilestoneId);
    final coverage = mockMilestone['coverage'] as double;
    final explain = mockMilestone['explainability'] ?? {};

    return SingleChildScrollView(
      key: const ValueKey('report'),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Verdict Banner Card
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.2), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PARTIALLY COMPLETED',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mockMilestone['milestoneTitle'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Audit Completed • 20 May 2025, 11:45 AM',
                        style: TextStyle(fontSize: 10, color: AppColors.outline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ReleaseConfidenceGauge(score: coverage, size: 60),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // AI Summary
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.outline)),
                const SizedBox(height: 8),
                Text(
                  explain['whyVerdictAssigned'] ?? 'Summary details.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 10),
                Text(
                  'Confidence Score: ${(mockMilestone['confidence'] as double).toInt()}%',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Key Findings Card
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Audit Key Findings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                _buildFindingsRow('Verified Requirements', '${mockMilestone['requirementsVerified']}', AppColors.tertiary),
                const Divider(),
                _buildFindingsRow('Partially Completed', '5', Colors.orange),
                const Divider(),
                _buildFindingsRow('Missing / Failed', '2', AppColors.error),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Top Issues Card
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Top Issues Identified', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                _buildIssueBullet('Event logging not implemented for all flows', Colors.orange),
                _buildIssueBullet('Dispute escalation not fully covered', Colors.orange),
                _buildIssueBullet('Unit test coverage below 60%', AppColors.error),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Evidence Snapshot Card
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Evidence Snapshot Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                _buildSnapshotRow('Snapshot Hash', _snapshotData?['sha256Hash'] ?? 'sha256-a9b8c7...'),
                const Divider(),
                _buildSnapshotRow('Latest Commit', (_snapshotData?['commitHashes'] as List?)?.first ?? 'b12c89f'),
                const Divider(),
                _buildSnapshotRow('PR References', _snapshotData?['prReferences'] ?? '#10, #11, #12'),
                const Divider(),
                _buildSnapshotRow('CI/CD Workflows', _snapshotData?['workflowRunReferences'] ?? 'Passed (Success)'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Escrow Release Recommendation and Button Gate
          _buildReleaseGateCard(mockMilestone),
        ],
      ),
    );
  }

  Widget _buildFindingsRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildIssueBullet(String text, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildSnapshotRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.outline)),
          Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildReleaseGateCard(Map<String, dynamic> milestone) {
    final status = milestone['status'] as String? ?? 'FAILED';
    final isPassed = status == 'PASSED';
    final confidenceScore = milestone['coverage'] as double;
    
    // release allowed if status is PASSED and confidence >= 70
    final canRelease = isPassed && confidenceScore >= 70.0;
    
    IconData icon = Icons.lock_outline;
    Color color = Colors.orange;
    String recText = 'RECOMMEND MINOR FIXES';
    String descText = 'Please address the incomplete requirements before requesting release.';
    
    if (isPassed) {
      icon = Icons.lock_open;
      color = AppColors.tertiary;
      recText = 'RECOMMEND RELEASE';
      descText = 'All audit conditions met. Payout release is cryptographically authorized.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BentoCard(
          color: color.withOpacity(0.04),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.outline,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // Sticky release button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canRelease ? AppColors.tertiary : AppColors.surfaceContainerHigh,
              foregroundColor: canRelease ? Colors.white : AppColors.outline,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: canRelease ? _approveRelease : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  canRelease ? Icons.lock_open : Icons.lock_outline,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Request Release',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            !isPassed
                ? 'Requires PASSED audit status'
                : (confidenceScore < 70.0 ? 'Requires confidence score >= 70% (Current: ${confidenceScore.toInt()}%)' : 'Authorized for cryptographic release'),
            style: const TextStyle(fontSize: 11, color: AppColors.outline),
          ),
        ),
        if (!canRelease) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _showFeedbackDialog,
              icon: const Icon(Icons.feedback_outlined, color: AppColors.primary, size: 18),
              label: const Text(
                'Request Rework / Fixes',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Helper mock data function
  Map<String, dynamic> _getMockMilestoneData(String milestoneId) {
    if (milestoneId == 'MS-1') {
      return {
        'milestoneId': 'MS-1',
        'milestoneTitle': 'Milestone 1 - Smart Contract Core',
        'status': 'PASSED',
        'coverage': 96.0,
        'confidence': 90.0,
        'requirementsVerified': 24,
        'totalRequirements': 25,
        'explainability': {
          'whyVerdictAssigned': 'All core contract functionality was found to be fully integrated with 96% unit test coverage and no safety concerns.',
          'evidenceUsed': '14 files, 8 commits, 3 PR approvals.',
          'missingImplementation': 'None. All tasks are completed.',
          'recommendedFixes': 'None. Ready for release.',
        },
        'requirementTraceMatrix': [
          {
            'requirementId': 'REQ-1',
            'requirementText': 'Escrow contract creation',
            'status': 'PASSED',
            'completionPercentage': 100,
            'confidenceScore': 100,
            'evidenceFiles': ['contracts/Escrow.sol', 'test/escrow.test.ts'],
            'evidenceCommits': ['a1b2c3d'],
            'evidencePRs': ['#1'],
          }
        ]
      };
    } else if (milestoneId == 'MS-3') {
      return {
        'milestoneId': 'MS-3',
        'milestoneTitle': 'Milestone 3 - Frontend Integration',
        'status': 'PENDING',
        'coverage': 0.0,
        'confidence': 0.0,
        'requirementsVerified': 0,
        'totalRequirements': 15,
        'explainability': {
          'whyVerdictAssigned': 'No commits or PR activities detected targeting frontend integration. Unit testing has not been configured.',
          'evidenceUsed': 'No files changed.',
          'missingImplementation': 'React widgets, state integration, backend synchronization hooks.',
          'recommendedFixes': 'Initialize UI integration branch, mount webhooks, and push initial repository files.',
        },
        'requirementTraceMatrix': []
      };
    } else {
      // MS-2 Default
      return {
        'milestoneId': 'MS-2',
        'milestoneTitle': 'Milestone 2 - Escrow Logic',
        'status': 'PARTIAL',
        'coverage': 72.0,
        'confidence': 84.0,
        'requirementsVerified': 18,
        'totalRequirements': 25,
        'explainability': {
          'whyVerdictAssigned': 'Core escrow logic is implemented successfully. Release mechanism needs improvement in dispute flow and event logging.',
          'evidenceUsed': 'Inspected files: contracts/Escrow.sol, test/escrow.test.ts, scripts/deploy.ts. Inspected 3 pull requests and 12 commits.',
          'missingImplementation': 'Event logging not implemented for all flows. Dispute escalation not fully covered. Unit test coverage below 60%.',
          'recommendedFixes': 'Implement the missing Event triggers on transfer and release. Add test coverage for dispute refund timeouts.',
        },
        'requirementTraceMatrix': [
          {
            'requirementId': 'REQ-1',
            'requirementText': 'Escrow contract creation',
            'status': 'PASSED',
            'completionPercentage': 100,
            'confidenceScore': 100,
            'evidenceFiles': ['contracts/Escrow.sol'],
            'evidenceCommits': ['c1234a9', 'd4567b1', 'e7890c2'],
            'evidencePRs': ['#10'],
          },
          {
            'requirementId': 'REQ-2',
            'requirementText': 'Deposit fund locking logic',
            'status': 'PASSED',
            'completionPercentage': 100,
            'confidenceScore': 100,
            'evidenceFiles': ['contracts/Escrow.sol', 'test/escrow.test.ts'],
            'evidenceCommits': ['f1234a9', 'g4567b1'],
            'evidencePRs': ['#11'],
          },
          {
            'requirementId': 'REQ-3',
            'requirementText': 'Multi-sig release mechanism',
            'status': 'PARTIAL',
            'completionPercentage': 60,
            'confidenceScore': 75,
            'evidenceFiles': ['contracts/Escrow.sol', 'test/escrow.test.ts'],
            'evidenceCommits': ['h1234a9'],
            'evidencePRs': [],
          },
          {
            'requirementId': 'REQ-4',
            'requirementText': 'Dispute handling flow',
            'status': 'PARTIAL',
            'completionPercentage': 70,
            'confidenceScore': 80,
            'evidenceFiles': ['contracts/Escrow.sol', 'test/escrow.test.ts'],
            'evidenceCommits': ['i1234a9'],
            'evidencePRs': ['#12'],
          },
          {
            'requirementId': 'REQ-5',
            'requirementText': 'Timeout & refund logic',
            'status': 'PASSED',
            'completionPercentage': 100,
            'confidenceScore': 100,
            'evidenceFiles': ['contracts/Escrow.sol', 'test/escrow.test.ts'],
            'evidenceCommits': ['j1234a9', 'k4567b1'],
            'evidencePRs': ['#13'],
          },
          {
            'requirementId': 'REQ-6',
            'requirementText': 'Event logging & tracking',
            'status': 'PARTIAL',
            'completionPercentage': 50,
            'confidenceScore': 60,
            'evidenceFiles': ['contracts/Escrow.sol'],
            'evidenceCommits': ['l1234a9'],
            'evidencePRs': [],
          },
          {
            'requirementId': 'REQ-7',
            'requirementText': 'Frontend escrow integration',
            'status': 'NOT_VERIFIED',
            'completionPercentage': 0,
            'confidenceScore': 0,
            'evidenceFiles': [],
            'evidenceCommits': [],
            'evidencePRs': [],
          },
          {
            'requirementId': 'REQ-8',
            'requirementText': 'Unit test coverage',
            'status': 'FAILED',
            'completionPercentage': 0,
            'confidenceScore': 35,
            'evidenceFiles': [],
            'evidenceCommits': [],
            'evidencePRs': [],
          },
        ]
      };
    }
  }
}

// Reusable Coverage Ring Widget
class CoverageRing extends StatelessWidget {
  final double coverage;
  final double size;
  final double strokeWidth;

  const CoverageRing({
    required this.coverage,
    this.size = 110,
    this.strokeWidth = 10,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: coverage / 100,
              strokeWidth: strokeWidth,
              backgroundColor: AppColors.outlineVariant.withOpacity(0.2),
              color: AppColors.primary,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${coverage.toInt()}%',
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                'Coverage',
                style: TextStyle(
                  fontSize: size * 0.09,
                  color: AppColors.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Reusable Circular Release Confidence Gauge Widget
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
            backgroundColor: AppColors.outlineVariant.withOpacity(0.15),
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
