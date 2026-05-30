import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/providers/realtime_providers.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/data/repository.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  bool _balanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiStateProvider);
    final repository = ref.watch(zeroPayRepositoryProvider);
    final priceFeed = ref.watch(priceFeedProvider).value ?? {'ADA': 0.40, 'USDC': 1.00, 'ETH': 3350.00};

    // Listen to real-time events and display as snackbar
    ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventProvider, (prev, next) {
      if (next.hasValue && next.value != null) {
        final event = next.value!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.surfaceContainerLowest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                Icon(
                  event.type == 'dispute' ? Icons.gavel : Icons.lock,
                  color: event.type == 'dispute' ? Colors.red : AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                      ),
                      Text(
                        event.message,
                        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(priceFeedProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(20.0),
            children: [

              // Render corresponding states
              if (uiState == AppUiState.loading) ...[
                _buildLoadingState(),
              ] else if (uiState == AppUiState.empty) ...[
                _buildEmptyState(),
              ] else if (uiState == AppUiState.error) ...[
                _buildErrorState(),
              ] else if (uiState == AppUiState.offline) ...[
                _buildOfflineBanner(),
                const SizedBox(height: 16),
                _buildNormalDashboard(repository, priceFeed),
              ] else ...[
                _buildNormalDashboard(repository, priceFeed),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Demo state toggler


  // State A: Loading state
  Widget _buildLoadingState() {
    return const LoadingStateView();
  }

  // State B: Empty state
  Widget _buildEmptyState() {
    return EmptyStateView(
      icon: Icons.account_balance_wallet_outlined,
      title: 'No Wallet Linked',
      description: 'Link or create a secure wallet signature to lock escrows and initiate commerce payments.',
      buttonText: 'Create Cardano Wallet',
      onButtonPressed: () {
        // Simulating wallet setup and restoring state
        ref.read(appUiStateProvider.notifier).state = AppUiState.normal;
      },
    );
  }

  // State C: Error state
  Widget _buildErrorState() {
    return ErrorStateView(
      title: 'Ledger Connection Failed',
      description: 'Unable to connect to the Cardano Mainnet node. Check your cellular data or try again later.',
      onRetry: () {
        ref.read(appUiStateProvider.notifier).state = AppUiState.normal;
      },
    );
  }

  // State D: Offline Banner
  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: const [
          Icon(Icons.wifi_off_outlined, color: Colors.orange),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Offline Mode: displaying cached balances and contract history from secure memory.',
              style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // State E: Normal Dashboard View
  Widget _buildNormalDashboard(ZeroPayRepository repository, Map<String, double> priceFeed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total Balance Section (Bento Style)
        _buildBalanceCard(repository, priceFeed),
        const SizedBox(height: 20),

        // Quick Actions Row (Glassmorphic)
        _buildQuickActionsRow(),
        const SizedBox(height: 24),

        // Multi-Chain Assets Carousel
        _buildAssetsCarousel(repository, priceFeed),
        const SizedBox(height: 24),

        // Two Column Bento Row (Active Escrows & Security Health)
        _buildBentoRow(repository),
        const SizedBox(height: 24),

        // AI Insights Feed
        _buildAiInsightsSection(repository),
      ],
    );
  }

  Widget _buildBalanceCard(ZeroPayRepository repository, Map<String, double> priceFeed) {
    return FutureBuilder<List<Asset>>(
      future: repository.getWalletAssets(),
      builder: (context, snapshot) {
        double totalBalance = 0;
        if (snapshot.hasData) {
          for (var asset in snapshot.data!) {
            final livePrice = priceFeed[asset.symbol] ?? (asset.fiatValue / asset.balance);
            totalBalance += asset.balance * livePrice;
          }
        } else {
          totalBalance = 124592.80; // Fallback hardcode
        }

        return BentoCard(
          child: Stack(
            children: [
              // Radial blur details
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.08),
                  ),
                ),
              ),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'TOTAL PORTFOLIO VALUE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _balanceVisible = !_balanceVisible),
                        child: Icon(
                          _balanceVisible ? Icons.visibility : Icons.visibility_off,
                          size: 16,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.outline,
                              fontWeight: FontWeight.w300,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _balanceVisible ? totalBalance.toStringAsFixed(2) : '•••••••',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1.0,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.tertiary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_upward, size: 12, color: AppColors.tertiary),
                        SizedBox(width: 4),
                        Text(
                          '+2.4% (24h)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.tertiary,
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
      },
    );
  }

  Widget _buildQuickActionsRow() {
    Widget buildActionBtn(IconData icon, String label, String route) {
      return Expanded(
        child: GestureDetector(
          onTap: () => context.go(route),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Icon(icon, color: AppColors.onPrimary, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          buildActionBtn(Icons.arrow_upward, 'Send', '/customer/wallet/send'),
          buildActionBtn(Icons.arrow_downward, 'Receive', '/customer/wallet/receive'),
          buildActionBtn(Icons.shopping_cart_outlined, 'Buy', '/customer/marketplace'),
          buildActionBtn(Icons.swap_horiz, 'Swap', '/customer/wallet'),
        ],
      ),
    );
  }

  Widget _buildAssetsCarousel(ZeroPayRepository repository, Map<String, double> priceFeed) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Assets',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => context.go('/customer/wallet'),
              child: const Text('View All'),
            ),
          ],
        ),
        FutureBuilder<List<Asset>>(
          future: repository.getWalletAssets(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No assets loaded.'));
            }

            final list = snapshot.data!;
            return SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final asset = list[index];
                  final livePrice = priceFeed[asset.symbol] ?? (asset.fiatValue / asset.balance);
                  final usdValue = asset.balance * livePrice;

                  return GestureDetector(
                    onTap: () => context.go('/customer/wallet/asset/${asset.symbol}'),
                    child: Container(
                      width: 250,
                      margin: const EdgeInsets.only(right: 14),
                      child: BentoCard(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Color(int.parse(asset.hexColor ?? '0xFF4648D4')),
                                      child: Text(
                                        asset.symbol[0],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          asset.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          asset.symbol,
                                          style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: asset.changePercent24h >= 0
                                        ? AppColors.tertiary.withOpacity(0.1)
                                        : AppColors.error.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${asset.changePercent24h >= 0 ? '+' : ''}${asset.changePercent24h.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: asset.changePercent24h >= 0 ? AppColors.tertiary : AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  asset.balance.toStringAsFixed(2),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                ),
                                Text(
                                  '≈ \$${usdValue.toStringAsFixed(2)} USD',
                                  style: const TextStyle(color: AppColors.outline, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBentoRow(ZeroPayRepository repository) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column 1: Active Escrows Stepper Preview
        Expanded(
          child: BentoCard(
            padding: const EdgeInsets.all(16.0),
            child: Builder(builder: (context) {
              final escrowAsync = ref.watch(customerEscrowsProvider);
              final escrowList = escrowAsync.valueOrNull ?? [];
              final count = escrowList.length;
              final activeEscrow = escrowList.isNotEmpty ? escrowList.first : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.lock_clock, color: AppColors.primary, size: 20),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
                        child: Text(
                          '$count',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Active Escrows',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  if (activeEscrow != null) ...[
                    Text(
                      activeEscrow.title,
                      style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Tiny Stepper
                    Row(
                      children: [
                        _buildMiniStepDot(true),
                        _buildMiniStepLine(true),
                        _buildMiniStepDot(true, isPulse: true),
                        _buildMiniStepLine(false),
                        _buildMiniStepDot(false),
                      ],
                    ),
                  ] else ...[
                    const Text('No locked contracts.', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                      ),
                      onPressed: () => context.go('/customer/escrow'),
                      child: const Text('View List', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(width: 12),

        // Column 2: Security Health Card
        Expanded(
          child: BentoCard(
            padding: const EdgeInsets.all(16.0),
            onTap: () => context.go('/customer/profile'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield, color: AppColors.tertiary, size: 20),
                const SizedBox(height: 12),
                const Text(
                  'Security Health',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildSecurityRow(Icons.check_circle, 'Enclave Active', AppColors.tertiary),
                const SizedBox(height: 6),
                _buildSecurityRow(Icons.check_circle, 'Biometric Setup', AppColors.tertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStepDot(bool active, {bool isPulse = false}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.primary : AppColors.surfaceContainerHigh,
        boxShadow: isPulse && active
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
    );
  }

  Widget _buildMiniStepLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        color: active ? AppColors.primary : AppColors.surfaceContainerHigh,
      ),
    );
  }

  Widget _buildSecurityRow(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAiInsightsSection(ZeroPayRepository repository) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.auto_awesome, color: AppColors.secondary, size: 18),
            SizedBox(width: 8),
            Text(
              'Lumina AI Insights',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<AIRecommendation>>(
          future: repository.getAIRecommendations(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const BentoCard(
                child: Center(
                  child: Text('AI engine is scanning transactions...', style: TextStyle(color: AppColors.outline)),
                ),
              );
            }

            final list = snapshot.data!;
            return Column(
              children: list.map((rec) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: BentoCard(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          rec.category == 'Negotiation' ? Icons.chat_outlined : Icons.monetization_on_outlined,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rec.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rec.description,
                                style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
