import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/data/repository.dart';

class ClientProfile {
  final String id;
  final String name;
  final String address;
  final double relationshipScore; // %
  final double trustScore; // %
  final int totalOrders;
  final double totalValueLocked;
  final int disputesCount;
  final String aiInsight;

  ClientProfile({
    required this.id,
    required this.name,
    required this.address,
    required this.relationshipScore,
    required this.trustScore,
    required this.totalOrders,
    required this.totalValueLocked,
    required this.disputesCount,
    required this.aiInsight,
  });
}

final reputationCrmProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(zeroPayRepositoryProvider);
  return await repo.getInvoicesList(limit: 50);
});

class ReputationCrmScreen extends ConsumerStatefulWidget {
  const ReputationCrmScreen({super.key});

  @override
  ConsumerState<ReputationCrmScreen> createState() => _ReputationCrmScreenState();
}

class _ReputationCrmScreenState extends ConsumerState<ReputationCrmScreen> {
  ClientProfile? _selectedClient;
  final List<ClientProfile> _clients = [];

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(reputationCrmProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reputation & CRM', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () {
            if (_selectedClient != null) {
              setState(() => _selectedClient = null);
            } else {
              context.go('/merchant/dashboard');
            }
          },
        ),
      ),
      body: invoicesAsync.when(
        loading: () => const SafeArea(child: LoadingStateView()),
        error: (err, stack) => ErrorStateView(
          title: 'Error loading CRM directory',
          description: err.toString(),
          onRetry: () => ref.invalidate(reputationCrmProvider),
          retryButtonText: 'Try Loading Again',
        ),
        data: (invoicesData) {
          final items = invoicesData['items'] ?? invoicesData['data']?['items'] as List? ?? [];
          final Map<String, List<Map<String, dynamic>>> grouped = {};

          for (var item in items) {
            final addr = (item['escrowCustomerAddress'] as String?) ?? 'Guest Customer (unregistered)';
            grouped.putIfAbsent(addr, () => []).add(item);
          }

          _clients.clear();
          int index = 1;
          grouped.forEach((address, invs) {
            double totalVal = 0.0;
            int disputes = 0;
            int orders = invs.length;

            for (var inv in invs) {
              final amountPaise = inv['amountPaise'] as num? ?? 0;
              final amountLovelace = inv['amountLovelace'] as num? ?? 0;
              final double amount = amountPaise > 0 ? (amountPaise / 100) : (amountLovelace / 1000000);
              totalVal += amount;

              if (inv['isDisputed'] == true || inv['escrowState'] == 'Disputed') {
                disputes++;
              }
            }

            final double trust = orders == 0 ? 100.0 : ((orders - disputes) / orders) * 100.0;
            final double relation = trust * 0.95; // slightly scaled

            // Format address for display
            String displayAddress = address;
            if (address.length > 20) {
              displayAddress = address.substring(0, 10) + '...' + address.substring(address.length - 8);
            }

            final name = address.startsWith('Guest')
                ? 'Guest Buyer'
                : 'Cardano Buyer #$index';
            index++;

            _clients.add(ClientProfile(
              id: address,
              name: name,
              address: displayAddress,
              relationshipScore: relation,
              trustScore: trust,
              totalOrders: orders,
              totalValueLocked: totalVal,
              disputesCount: disputes,
              aiInsight: disputes == 0
                  ? 'Highly trusted wallet. All escrow agreements completed and released successfully.'
                  : 'Has $disputes dispute(s) on-chain. Escrow protections recommended.',
            ));
          });

          // Update details reference if client was reloaded
          if (_selectedClient != null) {
            final matching = _clients.firstWhere((c) => c.id == _selectedClient!.id, orElse: () => _selectedClient!);
            _selectedClient = matching;
          }

          return _selectedClient == null
              ? _buildDirectoryBody()
              : _buildProfileDetailsBody(_selectedClient!);
        },
      ),
    );
  }

  Widget _buildDirectoryBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // CRM Overview metrics
        _buildCrmStatsCard(),
        const SizedBox(height: 20),
        
        Text('Customer Directory', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_clients.isEmpty)
          const Center(child: Text('No active customers linked to directory.', style: TextStyle(color: AppColors.outline)))
        else
          ..._clients.map((client) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: BentoCard(
                onTap: () => setState(() => _selectedClient = client),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.secondary.withOpacity(0.08),
                      child: Text(client.name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(client.address, style: const TextStyle(fontSize: 10, color: AppColors.outline)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Score: ${client.relationshipScore.toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                        const SizedBox(height: 2),
                        Text('${client.totalOrders} Orders', style: const TextStyle(fontSize: 9, color: AppColors.outline)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCrmStatsCard() {
    int totalLinked = _clients.length;
    double averageScore = _clients.isEmpty ? 0 : _clients.map((c) => c.relationshipScore).reduce((a, b) => a + b) / totalLinked;

    return BentoCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CRM Connected', style: TextStyle(fontSize: 11, color: AppColors.outline, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$totalLinked Customers', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(height: 40, width: 1, color: AppColors.outlineVariant.withOpacity(0.4)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Avg Relation Score', style: TextStyle(fontSize: 11, color: AppColors.outline, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${averageScore.toStringAsFixed(0)}% Health', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.tertiary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailsBody(ClientProfile client) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top Card Profile Summary
        BentoCard(
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.secondary.withOpacity(0.08),
                    child: Text(client.name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, fontSize: 18)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Cardano Wallet: ${client.address}', style: const TextStyle(fontSize: 9, color: AppColors.outline)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildProfileMetric('Relation Score', '${client.relationshipScore.toInt()}%', AppColors.secondary),
                  _buildProfileMetric('On-Chain Trust', '${client.trustScore.toStringAsFixed(1)}%', AppColors.tertiary),
                  _buildProfileMetric('Total Volume', '\$${client.totalValueLocked.toStringAsFixed(0)}', AppColors.primary),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // AI Trust Analysis
        Row(
          children: const [
            Icon(Icons.auto_awesome, color: AppColors.secondary, size: 16),
            SizedBox(width: 8),
            Text('Lumina AI Trust & Risk Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 10),
        BentoCard(
          padding: const EdgeInsets.all(16),
          border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('AI Risk Classification', style: TextStyle(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: client.trustScore >= 95.0 ? AppColors.tertiary.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      client.trustScore >= 95.0 ? 'LOW RISK' : 'MEDIUM RISK',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: client.trustScore >= 95.0 ? AppColors.tertiary : Colors.orange),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                client.aiInsight,
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // History Overview
        Text('Relationship History', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        BentoCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHistoryRow('Total Orders Initiated', '${client.totalOrders} Contracts'),
              const Divider(),
              _buildHistoryRow('Milestone Release disputes', '${client.disputesCount} Cases'),
              const Divider(),
              _buildHistoryRow('Dispute Settlement Ratio', client.disputesCount == 0 ? '100% (No disputes)' : '100% (Resolved consensually)'),
              const Divider(),
              _buildHistoryRow('Avg Settlement Speed', client.trustScore >= 95.0 ? '< 1 hour' : '12 - 24 hours'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick back button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() => _selectedClient = null),
            child: const Text('Back to Client Directory'),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileMetric(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.outline)),
      ],
    );
  }

  Widget _buildHistoryRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
          Text(desc, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
