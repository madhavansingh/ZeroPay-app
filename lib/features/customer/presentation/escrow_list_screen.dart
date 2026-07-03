import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/providers/global_providers.dart';

class EscrowListScreen extends ConsumerStatefulWidget {
  const EscrowListScreen({super.key});

  @override
  ConsumerState<EscrowListScreen> createState() => _EscrowListScreenState();
}

class _EscrowListScreenState extends ConsumerState<EscrowListScreen> {
  int _activeTab = 0; // 0: Active/Locked, 1: Completed, 2: Disputed

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Text(
                    'Smart Escrows',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: AppColors.outline),
                    onPressed: () {
                      // Explain escrow mechanism
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Operating Escrows'),
                          content: const Text(
                            'ZeroPay locks contract funds in decentralized Cardano/Ethereum smart contracts. Funds are only distributed to merchants upon buyer milestone confirmation or court consensus.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Tabs Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  _buildTab(0, 'Active & Locked'),
                  _buildTab(1, 'Completed'),
                  _buildTab(2, 'Disputed'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Escrows List
            Expanded(
              child: Builder(builder: (context) {
                final escrowAsync = ref.watch(customerEscrowsProvider);
                return escrowAsync.when(
                  loading: () => const LoadingStateView(),
                  error: (err, stack) => ErrorStateView(
                    title: 'Error loading escrows',
                    description: err.toString(),
                    onRetry: () => ref.invalidate(customerEscrowsProvider),
                  ),
                  data: (list) {
                  final filtered = list.where((escrow) {
                    if (_activeTab == 0) {
                      return escrow.status == 'Locked' || escrow.status == 'Active' || escrow.status == 'Pending';
                    } else if (_activeTab == 1) {
                      return escrow.status == 'Released' || escrow.status == 'Completed';
                    } else {
                      return escrow.status == 'Disputed' || escrow.status == 'Resolved';
                    }
                  }).toList();

                  if (filtered.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final escrow = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: BentoCard(
                          onTap: () => context.push('/customer/escrow/${escrow.id}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      escrow.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${escrow.totalValue} ${escrow.assetSymbol}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'To: ${escrow.counterpartyName}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                  ),
                                  Text(
                                    escrow.chainName,
                                    style: const TextStyle(fontSize: 10, color: AppColors.outline),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Milestone Progress Bar Indicator
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: _calculateMilestoneProgress(escrow),
                                        minHeight: 4,
                                        backgroundColor: AppColors.surfaceContainerHigh,
                                        color: _getEscrowStatusColor(escrow.status),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    escrow.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: _getEscrowStatusColor(escrow.status),
                                    ),
                                  ),
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
              },),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/escrow/builder'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Escrow',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primary : AppColors.outline,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateView(
      icon: Icons.history_toggle_off,
      title: 'No Contracts Here',
      description: 'No smart escrows found matching this lifecycle status.',
      buttonText: 'Create Smart Escrow',
      onButtonPressed: () => context.push('/escrow/builder'),
    );
  }

  double _calculateMilestoneProgress(Escrow escrow) {
    if (escrow.milestones.isEmpty) return 0.0;
    final released = escrow.milestones.where((element) => element.status == 'Released').length;
    return released / escrow.milestones.length;
  }

  Color _getEscrowStatusColor(String status) {
    switch (status) {
      case 'Locked':
      case 'Active':
        return AppColors.primary;
      case 'Released':
      case 'Completed':
        return AppColors.tertiary;
      case 'Disputed':
        return AppColors.error;
      default:
        return Colors.orange;
    }
  }
}
