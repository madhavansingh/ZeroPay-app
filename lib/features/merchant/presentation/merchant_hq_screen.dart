import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/data/repository.dart';
import '../../../shared/providers/global_providers.dart';

class MerchantHqScreen extends ConsumerStatefulWidget {
  const MerchantHqScreen({super.key});

  @override
  ConsumerState<MerchantHqScreen> createState() => _MerchantHqScreenState();
}

class _MerchantHqScreenState extends ConsumerState<MerchantHqScreen> {
  String _searchQuery = '';
  String _selectedStatusFilter = 'All'; // 'All', 'Locked', 'Released', 'Disputed'
  String _selectedSort = 'Date (Newest)';
  final Set<String> _selectedItemIds = {};
  bool _isBatchProcessing = false;

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(zeroPayRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Merchant HQ Operations', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () => context.go('/merchant/dashboard'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Search and filters bar
            _buildSearchAndFilters(),
            const SizedBox(height: 12),

            // Batch Actions row (visible only when items are selected)
            if (_selectedItemIds.isNotEmpty) _buildBatchActionsRow(repository),

            // Orders list
            Expanded(
              child: Builder(builder: (context) {
                final escrowAsync = ref.watch(merchantEscrowsProvider);
                return escrowAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => _buildEmptyHQState(),
                  data: (allEscrows) {
                  if (allEscrows.isEmpty) return _buildEmptyHQState();

                  // Apply search query and filters
                  var escrows = allEscrows.where((item) {
                    final matchQuery = item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        item.counterpartyName.toLowerCase().contains(_searchQuery.toLowerCase());
                    final matchStatus = _selectedStatusFilter == 'All' || item.status == _selectedStatusFilter;
                    return matchQuery && matchStatus;
                  }).toList();

                  // Apply sorting
                  if (_selectedSort == 'Date (Newest)') {
                    escrows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  } else if (_selectedSort == 'Value (Highest)') {
                    escrows.sort((a, b) => b.totalValue.compareTo(a.totalValue));
                  } else if (_selectedSort == 'Value (Lowest)') {
                    escrows.sort((a, b) => a.totalValue.compareTo(b.totalValue));
                  }

                  if (escrows.isEmpty) {
                    return EmptyStateView(
                      icon: Icons.search_off,
                      title: 'No Matching Orders',
                      description: 'No active orders matched your search query or status filters.',
                      buttonText: 'Reset Search Filters',
                      onButtonPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _selectedStatusFilter = 'All';
                        });
                      },
                    );
                  }

                  return ListView.builder(
                    itemCount: escrows.length,
                    itemBuilder: (context, index) {
                      final item = escrows[index];
                      final isSelected = _selectedItemIds.contains(item.id);
                      return _buildOrderRowCard(item, isSelected, repository);
                    },
                  );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        // Search bar
        TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search active orders, clients...',
            prefixIcon: const Icon(Icons.search, color: AppColors.outline),
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Filter choices & sorting
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Locked', 'Released', 'Disputed'].map((status) {
                    final isSel = _selectedStatusFilter == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(status, style: const TextStyle(fontSize: 11)),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) setState(() => _selectedStatusFilter = status);
                        },
                        selectedColor: AppColors.secondary.withOpacity(0.12),
                        labelStyle: TextStyle(
                          color: isSel ? AppColors.secondary : AppColors.onSurfaceVariant,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Sorting Dropdown
            DropdownButton<String>(
              value: _selectedSort,
              items: ['Date (Newest)', 'Value (Highest)', 'Value (Lowest)'].map((String val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                );
              }).toList(),
              onChanged: (newVal) {
                if (newVal != null) {
                  setState(() => _selectedSort = newVal);
                }
              },
              underline: const SizedBox(),
              icon: const Icon(Icons.sort, size: 16),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBatchActionsRow(ZeroPayRepository repository) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_selectedItemIds.length} items selected',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.secondary),
          ),
          Row(
            children: [
              if (_isBatchProcessing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary),
                )
              else ...[
                TextButton.icon(
                  onPressed: () async {
                    setState(() => _isBatchProcessing = true);
                    // Bulk simulate release request or fulfillment
                    await Future.delayed(const Duration(seconds: 1));
                    for (var id in _selectedItemIds) {
                      // releasing milestone ms_1 or active ones
                      try {
                        await repository.releaseMilestone(id, 'ms_gm_2');
                      } catch (_) {}
                    }
                    setState(() {
                      _selectedItemIds.clear();
                      _isBatchProcessing = false;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Batch milestones release updates pushed to ledger nodes.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.done_all, size: 14, color: AppColors.secondary),
                  label: const Text('Batch Release', style: TextStyle(fontSize: 12, color: AppColors.secondary)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: AppColors.secondary),
                  onPressed: () => setState(() => _selectedItemIds.clear()),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRowCard(Escrow item, bool isSelected, ZeroPayRepository repository) {
    Color statusColor = AppColors.primary;
    if (item.status == 'Released') statusColor = AppColors.tertiary;
    if (item.status == 'Disputed') statusColor = AppColors.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: BentoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row (Checkbox + Title + Status)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.secondary,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedItemIds.add(item.id);
                      } else {
                        _selectedItemIds.remove(item.id);
                      }
                    });
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text('Contract: ${item.id}', style: const TextStyle(fontSize: 10, color: AppColors.outline)),
                          const SizedBox(width: 8),
                          Text('• ${item.chainName}', style: const TextStyle(fontSize: 10, color: AppColors.outline)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.status,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            // Info Row (Counterparty + Amount + Progress)
            Padding(
              padding: const EdgeInsets.only(left: 48.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Counterparty', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                          Text(item.counterpartyName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Locked Volume', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                          Text('${item.totalValue} ${item.assetSymbol}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Milestone tracking progress
                  const Text('Milestones Status', style: TextStyle(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Column(
                    children: item.milestones.map((milestone) {
                      IconData milestoneIcon = Icons.pending_outlined;
                      Color iconColor = AppColors.outline;
                      if (milestone.status == 'Released') {
                        milestoneIcon = Icons.check_circle_outline;
                        iconColor = AppColors.tertiary;
                      } else if (milestone.status == 'In Progress') {
                        milestoneIcon = Icons.play_circle_outline;
                        iconColor = AppColors.primary;
                      } else if (milestone.status == 'Disputed') {
                        milestoneIcon = Icons.gavel;
                        iconColor = AppColors.error;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          children: [
                            Icon(milestoneIcon, size: 14, color: iconColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(milestone.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                            ),
                            Text(
                              '${milestone.amount} ${item.assetSymbol}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  // Dispatch buttons / shipping updates
                  if (item.status == 'Locked') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            minimumSize: const Size(0, 32),
                            side: const BorderSide(color: AppColors.secondary),
                          ),
                          onPressed: () {
                            // Go to escrow operations detail
                            context.go('/merchant/escrows');
                          },
                          icon: const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.secondary),
                          label: const Text('Ops Panel', style: TextStyle(fontSize: 11, color: AppColors.secondary)),
                        ),
                      ],
                    ),
                  ],
                  if (item.status == 'Disputed') ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: AppColors.error, size: 14),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Dispute Case is currently active. Submit evidence to local jury.',
                              style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 24),
                            ),
                            onPressed: () {
                              context.go('/merchant/escrows');
                            },
                            child: const Text('Details', style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHQState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox, size: 64, color: AppColors.outline),
          const SizedBox(height: 16),
          const Text('No Active Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Your store is synced but has no active orders in escrow.', style: TextStyle(color: AppColors.outline, fontSize: 12)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () => context.go('/merchant/dashboard'),
            child: const Text('Back to Dashboard'),
          ),
        ],
      ),
    );
  }
}
