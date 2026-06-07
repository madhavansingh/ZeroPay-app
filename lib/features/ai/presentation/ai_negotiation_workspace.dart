import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/widgets.dart';

class AiNegotiationWorkspace extends ConsumerStatefulWidget {
  const AiNegotiationWorkspace({super.key});

  @override
  ConsumerState<AiNegotiationWorkspace> createState() => _AiNegotiationWorkspaceState();
}

class _AiNegotiationWorkspaceState extends ConsumerState<AiNegotiationWorkspace> with SingleTickerProviderStateMixin {
  double _customerBid = 260.0;
  final double _merchantPrice = 299.0;
  final double _recommendedMin = 270.0;
  final double _recommendedMax = 285.0;
  final List<String> _proposalHistory = [
    'Merchant: Proposed \$299.00 USDC',
    'Customer: Proposed \$250.00 USDC',
    'AI Suggestion: Counter-offer \$275.00 USDC',
  ];

  late AnimationController _probabilityController;
  late Animation<double> _probabilityAnimation;

  @override
  void initState() {
    super.initState();
    _probabilityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _probabilityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_probabilityController);
    _probabilityController.forward();
  }

  @override
  void dispose() {
    _probabilityController.dispose();
    super.dispose();
  }

  double _calculateAgreementProbability(double bid) {
    if (bid >= _merchantPrice) return 1.0;
    if (bid < 220.0) return 0.05;

    // Standard sigmoid or linear model
    // 275 is the sweet spot
    if (bid >= _recommendedMin && bid <= _recommendedMax) {
      // higher probability range
      return 0.75 + ((bid - _recommendedMin) / (_recommendedMax - _recommendedMin)) * 0.20;
    } else if (bid < _recommendedMin) {
      return 0.10 + ((bid - 220.0) / (_recommendedMin - 220.0)) * 0.65;
    } else {
      return 0.90 + ((bid - _recommendedMax) / (_merchantPrice - _recommendedMax)) * 0.10;
    }
  }

  @override
  Widget build(BuildContext context) {
    final probability = _calculateAgreementProbability(_customerBid);
    _probabilityController.reset();
    _probabilityController.forward();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Price Negotiation', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () => context.canPop() ? context.pop() : context.go('/customer/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Pricing dashboard header
          _buildBiddingDashboard(probability),
          const SizedBox(height: 20),

          // Price sliders
          Text('Bidding & Proposing counter-offers', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          BentoCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Your counter-offer', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                    Text('\$${_customerBid.toStringAsFixed(2)} USDC', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary)),
                  ],
                ),
                Slider(
                  value: _customerBid,
                  min: 200.0,
                  max: 350.0,
                  divisions: 30,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() => _customerBid = val);
                  },
                ),
                // Recommendation highlight range
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Min Offer: \$200', style: TextStyle(fontSize: 9, color: AppColors.outline.withValues(alpha: 0.7))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                      child: const Text('AI Sweet Range: \$270 - \$285', style: TextStyle(fontSize: 9, color: AppColors.secondary, fontWeight: FontWeight.bold)),
                    ),
                    Text('Max Offer: \$350', style: TextStyle(fontSize: 9, color: AppColors.outline.withValues(alpha: 0.7))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Negotiation timelines & history
          Text('Discussion Timeline History', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          BentoCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._proposalHistory.map((item) {
                  final isAi = item.contains('AI');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          isAi ? Icons.auto_awesome : Icons.person_outline,
                          size: 14,
                          color: isAi ? AppColors.secondary : AppColors.outline,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isAi ? FontWeight.bold : FontWeight.normal,
                              color: isAi ? AppColors.secondary : AppColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _proposalHistory.add('Customer counter-offer: \$${_customerBid.toStringAsFixed(2)} USDC');
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Pushed counter-proposal \$${_customerBid.toStringAsFixed(2)} to merchant.')),
                        );
                      },
                      child: const Text('Propose Offer', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Volatility Risk Signals
          BentoCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI RISK SIGNALS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.outline)),
                const SizedBox(height: 10),
                _buildRiskRow('Counterparty volatility risk', 'Low', AppColors.tertiary),
                const SizedBox(height: 6),
                _buildRiskRow('Collateral conversion slippage', '0.2%', AppColors.tertiary),
                const SizedBox(height: 6),
                _buildRiskRow('Estimated smart contract transaction gas fee', '0.35 ADA', AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiddingDashboard(double probability) {
    return BentoCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Merchant Asking', style: TextStyle(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('\$${_merchantPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                const Text('AI Target Recommendation', style: TextStyle(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('\$275.00 USDC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.secondary)),
              ],
            ),
          ),
          Container(height: 90, width: 1, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Column(
                children: [
                  const Text('Agreement Prob', style: TextStyle(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: AnimatedBuilder(
                      animation: _probabilityAnimation,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: NegotiationGaugePainter(probability * _probabilityAnimation.value),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskRow(String label, String value, Color col) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col)),
      ],
    );
  }
}

// Custom Painter: Negotiation Agreement Gauge
class NegotiationGaugePainter extends CustomPainter {
  final double val; // 0.0 to 1.0

  NegotiationGaugePainter(this.val);

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track arc
    final trackPaint = Paint()
      ..color = AppColors.surfaceContainerHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.8,
      math.pi * 1.4,
      false,
      trackPaint,
    );

    // Active sweep arc
    Color activeColor = AppColors.error;
    if (val > 0.40) activeColor = Colors.orange;
    if (val > 0.70) activeColor = AppColors.tertiary;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.8,
      math.pi * 1.4 * val,
      false,
      activePaint,
    );

    // Display Text in center
    final textSpan = TextSpan(
      text: '${(val * 100).toInt()}%',
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: activeColor),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant NegotiationGaugePainter oldDelegate) => oldDelegate.val != val;
}
