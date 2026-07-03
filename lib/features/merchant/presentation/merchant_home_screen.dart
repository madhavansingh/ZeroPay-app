import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/providers/realtime_providers.dart';
import '../../../shared/data/repository.dart';

class MerchantHomeScreen extends ConsumerStatefulWidget {
  const MerchantHomeScreen({super.key});

  @override
  ConsumerState<MerchantHomeScreen> createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends ConsumerState<MerchantHomeScreen> {
  bool _revenueVisible = true;

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiStateProvider);
    final currentDataset = ref.watch(scenarioProfileProvider);
    final repository = ref.watch(zeroPayRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // refresh data
            ref.invalidate(zeroPayRepositoryProvider);
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
                _buildNormalDashboard(repository, currentDataset),
              ] else ...[
                _buildNormalDashboard(repository, currentDataset),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Task 10: Scenario selection UI panel


  // Loading skeleton state
  Widget _buildLoadingState() {
    return const Column(
      children: [
        LoadingSkeleton(height: 180, radius: 24),
        SizedBox(height: 16),
        LoadingSkeleton(height: 100, radius: 16),
        SizedBox(height: 24),
        LoadingSkeleton(height: 150, radius: 24),
        SizedBox(height: 16),
        LoadingSkeleton(height: 130, radius: 24),
      ],
    );
  }

  // Empty state view
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.store_outlined,
              size: 80,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Storefront Inactive',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'You have no active products, escrows, or revenues. Create your first catalog item to start receiving Web3 payments.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 28),
          GradientButton(
            text: 'Setup Store Catalog',
            onPressed: () {
              ref.read(appUiStateProvider.notifier).state = AppUiState.normal;
              context.go('/merchant/store');
            },
          ),
        ],
      ),
    );
  }

  // Error state view
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0x1ABA1A1A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: AppColors.error, size: 64),
            ),
            const SizedBox(height: 20),
            Text(
              'Failed to Sync Telemetry',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'ZeroPay was unable to establish a secure websocket sync with the smart contract event relay queue.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
              onPressed: () {
                ref.read(appUiStateProvider.notifier).state = AppUiState.normal;
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }

  // Offline banner widget
  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.orange, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Offline Mode: Running on cached ledger nodes. Payment releases are queued locally.',
              style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Normal command dashboard
  Widget _buildNormalDashboard(ZeroPayRepository repository, ScenarioProfile dataset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Revenue Card
        _buildRevenueBentoCard(dataset),
        const SizedBox(height: 20),

        // Quick Navigation Grid
        _buildNavigationGrid(),
        const SizedBox(height: 24),

        // Active Escrows & Release Requests Bento
        _buildEscrowPipelinePanel(repository),
        const SizedBox(height: 24),

        // Webhook & Settlement Health Indicators
        _buildHealthTelemetryRow(dataset),
        const SizedBox(height: 24),

        // AI Commerce Insights & Alerts
        _buildAiRecommendationsSection(repository),
      ],
    );
  }

  // Today's Revenue & Month's Revenue with sparkline painter
  Widget _buildRevenueBentoCard(ScenarioProfile dataset) {
    double revenueToday = 0;
    double revenueMonth = 0;
    List<double> sparkPoints = [];

    // Dynamically calculate values from active dataset profile
    switch (dataset) {
      case ScenarioProfile.smallMerchant:
        revenueToday = 50.00;
        revenueMonth = 420.00;
        sparkPoints = [10.0, 15.0, 8.0, 12.0, 45.0, 50.0];
        break;
      case ScenarioProfile.growingMerchant:
        revenueToday = 2500.00;
        revenueMonth = 34500.00;
        sparkPoints = [800, 1200, 1800, 1400, 2200, 2500];
        break;
      case ScenarioProfile.enterpriseMerchant:
        revenueToday = 145200.00;
        revenueMonth = 2840000.00;
        sparkPoints = [110000, 95000, 130000, 115000, 140000, 145200];
        break;
      case ScenarioProfile.marketplaceSeller:
        revenueToday = 450.00;
        revenueMonth = 9200.00;
        sparkPoints = [150, 300, 200, 550, 320, 450];
        break;
      default:
        revenueToday = 1200.00;
        revenueMonth = 15800.00;
        sparkPoints = [400, 900, 600, 1500, 1100, 1200];
    }

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REVENUE PERFORMANCE OVERVIEW',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: Icon(
                  _revenueVisible ? Icons.visibility : Icons.visibility_off,
                  size: 16,
                  color: AppColors.onSurfaceVariant,
                ),
                onPressed: () => setState(() => _revenueVisible = !_revenueVisible),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.outline),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _revenueVisible ? '\$${revenueToday.toStringAsFixed(2)}' : '••••••',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Month',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.outline),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _revenueVisible ? '\$${revenueMonth.toStringAsFixed(2)}' : '••••••',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Custom Sparkline Chart
          Text(
            'Earnings Trend (Last 6h)',
            style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant.withValues(alpha: 0.7), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            width: double.infinity,
            child: CustomPaint(
              painter: SparklinePainter(sparkPoints, AppColors.secondary),
            ),
          ),
        ],
      ),
    );
  }

  // Quick Navigation Grid to sub pages
  Widget _buildNavigationGrid() {
    Widget buildNavBtn(IconData icon, String label, String route, Color color) {
      return BentoCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        onTap: () {
          if (route == '/merchant/store' || route == '/merchant/escrows') {
            context.go(route);
          } else {
            context.push(route);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Commerce Hub',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.0,
          children: [
            buildNavBtn(Icons.storefront_outlined, 'Store Catalog', '/merchant/store', AppColors.primary),
            buildNavBtn(Icons.assignment_turned_in_outlined, 'HQ Operations', '/merchant/hq', AppColors.secondary),
            buildNavBtn(Icons.lock_person_outlined, 'Escrow Center', '/merchant/escrows', AppColors.tertiary),
            buildNavBtn(Icons.account_balance_wallet_outlined, 'Payout Center', '/merchant/payout', Colors.teal),
            buildNavBtn(Icons.auto_awesome_outlined, 'AI Optimizers', '/merchant/insights', Colors.orange),
            buildNavBtn(Icons.terminal, 'Telemetry Logs', '/merchant/telemetry', Colors.red),
          ],
        ),
      ],
    );
  }

  // Active Escrows list panel
  Widget _buildEscrowPipelinePanel(ZeroPayRepository repository) {
    final escrowAsync = ref.watch(merchantEscrowsProvider);
    final escrows = escrowAsync.valueOrNull ?? [];
    final activeCount = escrows.where((e) => e.status == 'Locked' || e.status == 'Pending' || e.status == 'Active').length;
    final releasePending = escrows.where((e) => e.milestones.any((m) => m.status == 'In Progress')).length;

    return BentoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ESCROW PIPELINE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton(
                onPressed: () => context.go('/merchant/escrows'),
                child: const Text('View Operations', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Active Escrows', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                      const SizedBox(height: 4),
                      Text(
                        '$activeCount',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pending Release', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                      const SizedBox(height: 4),
                      Text(
                        '$releasePending',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.tertiary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (escrows.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Recent Escrow Activity', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.outline)),
            const SizedBox(height: 8),
            Column(
              children: escrows.take(2).map((escrow) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(escrow.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(escrow.counterpartyName, style: const TextStyle(fontSize: 10, color: AppColors.outline)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: escrow.status == 'Disputed' ? Colors.red.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          escrow.status,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: escrow.status == 'Disputed' ? Colors.red : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // Telemetry statuses
  Widget _buildHealthTelemetryRow(ScenarioProfile dataset) {
    String webhookStatus = 'Operational';
    Color webhookColor = AppColors.tertiary;
    String settlementSpeed = '1.2 mins';

    if (dataset == ScenarioProfile.enterpriseMerchant) {
      webhookStatus = 'Degraded (502 Gateway)';
      webhookColor = Colors.orange;
      settlementSpeed = '2.5 mins';
    }

    return BentoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OPERATIONAL HEALTH & TELEMETRY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Settlement Latency', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.speed, size: 14, color: AppColors.tertiary),
                        const SizedBox(width: 4),
                        Text(settlementSpeed, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Webhook Health', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: webhookColor),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            webhookStatus,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: webhookColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  // AI recommendations panel
  Widget _buildAiRecommendationsSection(ZeroPayRepository repository) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.secondary, size: 18),
            SizedBox(width: 8),
            Text(
              'Lumina Business Advisor',
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
                  child: Text('Evaluating store catalog pricing...', style: TextStyle(color: AppColors.outline)),
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
                        const Icon(Icons.lightbulb_outline, color: AppColors.secondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    rec.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${(rec.confidenceScore * 100).toInt()}% conf',
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.secondary),
                                    ),
                                  ),
                                ],
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

// Sparkline custom painter
class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = size.width / (data.length - 1);

    final maxVal = data.reduce((curr, next) => curr > next ? curr : next);
    final minVal = data.reduce((curr, next) => curr < next ? curr : next);
    final valRange = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final percentY = (data[i] - minVal) / valRange;
      final y = size.height - (percentY * size.height * 0.8) - (size.height * 0.1);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Gradient fill below path
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) => oldDelegate.data != data;
}
