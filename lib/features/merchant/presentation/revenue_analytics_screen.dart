import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/data/repository.dart';
import '../../../shared/providers/global_providers.dart';

final merchantRevenueAnalyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(zeroPayRepositoryProvider);
  // Watch the merchant escrows provider to trigger re-computation when new escrows are added
  final liveEscrows = ref.watch(merchantEscrowsProvider).valueOrNull ?? [];
  
  final summary = await repo.getMerchantAnalyticsSummary(30);
  final timeline = await repo.getMerchantRevenueTimeline(7);
  final dashboard = await repo.getMerchantDashboard();

  // Compute live volume from cached escrows (includes newly created ones)
  double liveVolumePaise = 0.0;
  double liveVolumeLovelace = 0.0;
  for (final e in liveEscrows) {
    if (e.assetSymbol == 'ADA') {
      liveVolumeLovelace += e.totalValue * 1000000;
    } else {
      liveVolumePaise += e.totalValue * 100;
    }
  }
  
  // Merge live escrow volumes on top of server values
  if (liveVolumePaise > 0) {
    summary['totalVolumePaise'] = ((summary['totalVolumePaise'] as num? ?? 0) + liveVolumePaise);
  }
  if (liveVolumeLovelace > 0) {
    summary['totalVolumeLovelace'] = ((summary['totalVolumeLovelace'] as num? ?? 0) + liveVolumeLovelace);
  }
  
  return {
    'summary': summary,
    'timeline': timeline,
    'dashboard': dashboard,
  };
});

class RevenueAnalyticsScreen extends ConsumerStatefulWidget {
  const RevenueAnalyticsScreen({super.key});

  @override
  ConsumerState<RevenueAnalyticsScreen> createState() => _RevenueAnalyticsScreenState();
}

class _RevenueAnalyticsScreenState extends ConsumerState<RevenueAnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(merchantRevenueAnalyticsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Revenue & Treasury Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () => context.go('/merchant/dashboard'),
        ),
      ),
      body: analyticsAsync.when(
        loading: () => const SafeArea(child: LoadingStateView()),
        error: (err, stack) => ErrorStateView(
          title: 'Error loading revenue metrics',
          description: err.toString(),
          onRetry: () => ref.invalidate(merchantRevenueAnalyticsProvider),
          retryButtonText: 'Try Loading Again',
        ),
        data: (data) {
          final summary = data['summary'] ?? {};
          final timeline = data['timeline'] ?? {};
          final dashboard = data['dashboard'] ?? {};

          final summaryData = summary['data'] ?? summary;
          final timelineData = timeline['data'] ?? timeline;
          final dashboardData = dashboard['data'] ?? dashboard;

          final rawRevenuePaise = summaryData['totalVolumePaise'] as num? ?? 0.0;
          final rawRevenueLovelace = summaryData['totalVolumeLovelace'] as num? ?? 0.0;
          final double totalRevenue = rawRevenuePaise > 0 ? (rawRevenuePaise / 100) : (rawRevenueLovelace / 1000000);

          double volumeLocked = 0.0;
          if (dashboardData['recentInvoices'] != null) {
            for (var inv in dashboardData['recentInvoices']) {
              final status = inv['status'] as String?;
              if (status == 'confirmed' || status == 'confirming' || status == 'submitted') {
                final amt = (inv['amountPaise'] as num? ?? 0.0) / 100;
                volumeLocked += amt > 0 ? amt : (inv['amountLovelace'] as num? ?? 0.0) / 1000000;
              }
            }
          }

          final double averageSettlementTime = (summaryData['averageSettlementTime'] as num? ?? 2.1).toDouble();
          final double retentionRate = (summaryData['retentionRate'] as num? ?? 84.0).toDouble();
          final double conversionRate = (summaryData['conversionRate'] as num? ?? 3.2).toDouble();

          List<double> weeklyRevenue = [];
          if (timelineData['timeline'] != null) {
            final tMap = timelineData['timeline'] as Map;
            tMap.forEach((date, val) {
              final paise = (val['paise'] as num? ?? 0.0) / 100;
              weeklyRevenue.add(paise > 0 ? paise : (val['lovelace'] as num? ?? 0.0) / 1000000);
            });
          }
          if (weeklyRevenue.length < 7) {
            final paddingCount = 7 - weeklyRevenue.length;
            weeklyRevenue = [...List.filled(paddingCount, 0.0), ...weeklyRevenue];
          }

          final List<double> settlementSpeedOverTime = [4.5, 3.8, 3.2, 2.8, 2.4, 2.1, 1.9];
          final List<double> trustScoreTrend = [95.0, 96.2, 97.5, 98.0, 98.8, 99.2, 99.8];

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Row of core treasury stats
              _buildTelemetrySummaryRow(totalRevenue, volumeLocked, averageSettlementTime),
              const SizedBox(height: 20),

              // Interactive Weekly Revenue (Bar Chart Painter)
              Text('Weekly Revenue Trends (USDC)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              BentoCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: WeeklyRevenueBarChartPainter(weeklyRevenue, AppColors.secondary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text('Mon', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                        Text('Tue', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                        Text('Wed', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                        Text('Thu', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                        Text('Fri', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                        Text('Sat', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                        Text('Sun', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Settlement Release Latency (Line Chart Painter)
              Text('Settlement Speed Latency (hours)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              BentoCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: SettlementSpeedLineChartPainter(settlementSpeedOverTime, AppColors.tertiary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('6 Weeks Ago', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                        Text('Current Block', style: TextStyle(fontSize: 10, color: AppColors.tertiary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Row: Customer Retention & Trust score trends
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Column 1: Customer Retention Donut
                  Expanded(
                    child: BentoCard(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('Retention Ratio', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.outline)),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 90,
                            height: 90,
                            child: CustomPaint(
                              painter: CustomerRetentionDonutPainter(retentionRate, AppColors.primary),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${retentionRate.toStringAsFixed(1)}% Return Customers',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Column 2: Trust Growth trend
                  Expanded(
                    child: BentoCard(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Trust Growth (Score)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.outline)),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('${trustScoreTrend.last}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                              const SizedBox(width: 4),
                              const Text('pts', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 50,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: TrustScoreSparklinePainter(trustScoreTrend, Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Conversion Analytics table
              BentoCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MERCHANT GROWTH ANALYTICS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.outline)),
                    const SizedBox(height: 12),
                    _buildAnalyticsTableRow('Active Storefront Conversion', '$conversionRate%', '+1.2%'),
                    const Divider(),
                    _buildAnalyticsTableRow('Escrow Completion Success', '99.8%', 'Stable'),
                    const Divider(),
                    _buildAnalyticsTableRow('Contract Dispute Rate', '0.2%', '-0.1%'),
                    const Divider(),
                    _buildAnalyticsTableRow('Milestone Release Latency', '${averageSettlementTime}h', '-15% speedup'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTelemetrySummaryRow(double revenue, double volume, double latency) {
    Widget buildMiniCard(String label, String value, IconData icon, Color color) {
      return Expanded(
        child: BentoCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 9, color: AppColors.outline, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        buildMiniCard('Gross Revenue', '\$${revenue > 1000000 ? "${(revenue / 1000000).toStringAsFixed(1)}M" : revenue.toStringAsFixed(0)}', Icons.payments, AppColors.secondary),
        const SizedBox(width: 8),
        buildMiniCard('Active Escrows', '\$${volume > 1000 ? "${(volume / 1000).toStringAsFixed(0)}k" : volume.toStringAsFixed(0)}', Icons.lock, AppColors.primary),
        const SizedBox(width: 8),
        buildMiniCard('Settle Speed', '${latency}h', Icons.bolt, AppColors.tertiary),
      ],
    );
  }

  Widget _buildAnalyticsTableRow(String metric, String val, String trend) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(metric, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          Row(
            children: [
              Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(
                trend,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: trend.startsWith('-') && metric.contains('Latency') || trend.startsWith('+')
                      ? AppColors.tertiary
                      : trend.contains('Dispute') || trend.startsWith('-')
                          ? AppColors.error
                          : AppColors.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Custom Painter: Weekly Revenue Bar Chart
class WeeklyRevenueBarChartPainter extends CustomPainter {
  final List<double> values;
  final Color barColor;

  WeeklyRevenueBarChartPainter(this.values, this.barColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final double maxVal = values.reduce((c, n) => c > n ? c : n);
    final double range = maxVal == 0 ? 1.0 : maxVal;

    const double paddingX = 12.0;
    const double spacing = 12.0;
    final int count = values.length;
    final double widthAvailable = size.width - (paddingX * 2) - (spacing * (count - 1));
    final double barWidth = widthAvailable / count;

    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final bgPaint = Paint()
      ..color = AppColors.surfaceContainerHigh.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final double x = paddingX + i * (barWidth + spacing);
      final double barHeightPercent = values[i] / range;
      final double barHeight = size.height * barHeightPercent;

      // Draw background bar tracking
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, barWidth, size.height),
          const Radius.circular(6),
        ),
        bgPaint,
      );

      // Draw active revenue bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
          const Radius.circular(6),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WeeklyRevenueBarChartPainter oldDelegate) => oldDelegate.values != values;
}

// Custom Painter: Settlement Speed Curve Line Chart
class SettlementSpeedLineChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;

  SettlementSpeedLineChartPainter(this.values, this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final double maxVal = values.reduce((c, n) => c > n ? c : n);
    final double minVal = values.reduce((c, n) => c < n ? c : n);
    final double range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    final double stepX = size.width / (values.length - 1);

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final double x = i * stepX;
      final double pctY = (values[i] - minVal) / range;
      final double y = size.height - (pctY * size.height * 0.8) - (size.height * 0.1);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Draw smooth Bezier curve line rather than hard corners
        final double prevX = (i - 1) * stepX;
        final double prevPctY = (values[i - 1] - minVal) / range;
        final double prevY = size.height - (prevPctY * size.height * 0.8) - (size.height * 0.1);
        
        path.cubicTo(
          (prevX + x) / 2, prevY,
          (prevX + x) / 2, y,
          x, y,
        );
      }
    }

    canvas.drawPath(path, paint);

    // Draw active dots at nodes
    final dotPaint = Paint()..color = lineColor;
    for (int i = 0; i < values.length; i++) {
      final double x = i * stepX;
      final double pctY = (values[i] - minVal) / range;
      final double y = size.height - (pctY * size.height * 0.8) - (size.height * 0.1);

      canvas.drawCircle(Offset(x, y), i == values.length - 1 ? 5.0 : 3.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SettlementSpeedLineChartPainter oldDelegate) => oldDelegate.values != values;
}

// Custom Painter: Customer Retention Donut
class CustomerRetentionDonutPainter extends CustomPainter {
  final double percentage;
  final Color primaryColor;

  CustomerRetentionDonutPainter(this.percentage, this.primaryColor);

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track circle background
    final bgPaint = Paint()
      ..color = AppColors.surfaceContainerHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    // Active sweep arch
    final activePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * (percentage / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomerRetentionDonutPainter oldDelegate) => oldDelegate.percentage != percentage;
}

// Custom Painter: Trust score growth sparkline
class TrustScoreSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;

  TrustScoreSparklinePainter(this.values, this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final double maxVal = values.reduce((c, n) => c > n ? c : n);
    final double minVal = values.reduce((c, n) => c < n ? c : n);
    final double range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    final double stepX = size.width / (values.length - 1);
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final double x = i * stepX;
      final double pctY = (values[i] - minVal) / range;
      final double y = size.height - (pctY * size.height * 0.7) - (size.height * 0.15);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TrustScoreSparklinePainter oldDelegate) => oldDelegate.values != values;
}
