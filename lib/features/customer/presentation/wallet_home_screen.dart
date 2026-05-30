import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/data/repository.dart';

class WalletHomeScreen extends ConsumerWidget {
  const WalletHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(zeroPayRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            Text(
              'My Wallet',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your multi-chain digital assets and smart ledger.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Portfolio Allocation Card
            _buildAllocationCard(repository, context),
            const SizedBox(height: 24),

            // Quick Actions Row
            _buildQuickActionsRow(context),
            const SizedBox(height: 28),

            // Asset Breakdown List
            Text(
              'Assets',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildAssetList(repository),
            const SizedBox(height: 28),

            // Recent Transactions List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction History',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.history, color: AppColors.outline, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            _buildTransactionList(repository),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationCard(ZeroPayRepository repository, BuildContext context) {
    return FutureBuilder<List<Asset>>(
      future: repository.getWalletAssets(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return BentoCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Text(
                  'Failed to load assets: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const BentoCard(child: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const BentoCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Text('No assets in wallet.', style: TextStyle(color: AppColors.outline, fontSize: 12)),
              ),
            ),
          );
        }

        final list = snapshot.data!;
        double totalValue = list.fold(0, (sum, item) => sum + item.fiatValue);

        return BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PORTFOLIO ALLOCATION',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Simulated Allocation Ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: 0.7,
                          strokeWidth: 10,
                          backgroundColor: Colors.purple.withOpacity(0.2),
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '100%',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  // Legends
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: list.map((asset) {
                        final percent = (asset.fiatValue / totalValue) * 100;
                        final color = Color(int.parse(asset.hexColor ?? '0xFF4648D4'));
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                                  const SizedBox(width: 8),
                                  Text(asset.symbol, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Text('${percent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    Widget buildAction(IconData icon, String label, String route) {
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (route == '/customer/marketplace' || route == '/customer/wallet') {
              context.go(route);
            } else {
              context.push(route);
            }
          },
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        buildAction(Icons.arrow_upward, 'Send', '/customer/wallet/send'),
        buildAction(Icons.arrow_downward, 'Receive', '/customer/wallet/receive'),
        buildAction(Icons.shopping_cart_outlined, 'Buy', '/customer/marketplace'),
        buildAction(Icons.swap_horiz, 'Swap', '/customer/wallet'),
      ],
    );
  }

  Widget _buildAssetList(ZeroPayRepository repository) {
    return FutureBuilder<List<Asset>>(
      future: repository.getWalletAssets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final list = snapshot.data!;

        return Column(
          children: list.map((asset) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: BentoCard(
                onTap: () => context.push('/customer/wallet/asset/${asset.symbol}'),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(int.parse(asset.hexColor ?? '0xFF4648D4')),
                      child: Text(asset.symbol[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(asset.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(asset.symbol, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          asset.balance.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '\$${asset.fiatValue.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.outline, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTransactionList(ZeroPayRepository repository) {
    return FutureBuilder<List<Transaction>>(
      future: repository.getTransactions(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return BentoCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Text(
                  'Failed to load transactions: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const BentoCard(child: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return BentoCard(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: EmptyStateView(
              icon: Icons.history,
              title: 'No Transactions',
              description: 'You have not made any token transfers or escrow locks yet.',
              buttonText: 'Transfer Tokens',
              onButtonPressed: () => context.push('/customer/wallet/send'),
            ),
          );
        }

        final list = snapshot.data!;
        return Column(
          children: list.map((tx) {
            final isSend = tx.type == 'Send' || tx.type == 'Escrow Lock';
            Color statusColor = AppColors.tertiary;
            if (tx.status == 'Pending') statusColor = Colors.orange;
            if (tx.status == 'Failed') statusColor = AppColors.error;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: BentoCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isSend ? AppColors.error.withOpacity(0.08) : AppColors.tertiary.withOpacity(0.08),
                      child: Icon(
                        isSend ? Icons.arrow_outward : Icons.call_received,
                        size: 16,
                        color: isSend ? AppColors.error : AppColors.tertiary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            tx.counterpartyAddress,
                            style: const TextStyle(color: AppColors.outline, fontSize: 11, fontFamily: 'monospace'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isSend ? '-' : '+'}${tx.amount} ${tx.assetSymbol}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isSend ? AppColors.error : AppColors.tertiary,
                          ),
                        ),
                        Text(
                          tx.status,
                          style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
