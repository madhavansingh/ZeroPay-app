import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/data/repository.dart';

class AssetDetailsScreen extends ConsumerWidget {
  final String symbol;
  const AssetDetailsScreen({required this.symbol, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(zeroPayRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => context.canPop() ? context.pop() : context.go('/customer/wallet'),
        ),
        title: Text(
          '$symbol Wallet',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface),
        ),
      ),
      body: FutureBuilder<List<Asset>>(
        future: repository.getWalletAssets(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final asset = snapshot.data!.firstWhere(
            (e) => e.symbol.toUpperCase() == symbol.toUpperCase(),
            orElse: () => Asset(symbol: symbol, name: 'Digital Asset', balance: 0.0, fiatValue: 0.0, changePercent24h: 0.0),
          );

          return ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              // Token Value Header
              _buildTokenHeader(context, asset),
              const SizedBox(height: 24),

              // Sparkline Price Trend Chart
              _buildPriceTrendCard(context, asset),
              const SizedBox(height: 24),

              // Address Copier Card
              _buildAddressCopierCard(context),
              const SizedBox(height: 24),

              // Ledger Transactions List
              Text(
                'Recent $symbol Transactions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildFilteredTransactions(repository, asset.symbol),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTokenHeader(BuildContext context, Asset asset) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Color(int.parse(asset.hexColor ?? '0xFF4648D4')),
          child: Text(
            asset.symbol[0],
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${asset.balance.toStringAsFixed(4)} ${asset.symbol}',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '≈ \$${asset.fiatValue.toStringAsFixed(2)} USD',
          style: const TextStyle(color: AppColors.outline, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildPriceTrendCard(BuildContext context, Asset asset) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PRICE TREND (24H)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '${asset.changePercent24h >= 0 ? '+' : ''}${asset.changePercent24h}%',
                style: TextStyle(
                  color: asset.changePercent24h >= 0 ? AppColors.tertiary : AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Custom Painter Sparkline
          SizedBox(
            height: 80,
            width: double.infinity,
            child: CustomPaint(
              painter: SparklinePainter(
                points: asset.changePercent24h >= 0
                    ? [10, 15, 8, 22, 19, 32, 28, 45]
                    : [45, 38, 41, 29, 32, 20, 24, 10],
                lineColor: asset.changePercent24h >= 0 ? AppColors.tertiary : AppColors.error,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('24h ago', style: TextStyle(fontSize: 10, color: AppColors.outline)),
              Text('Live', style: TextStyle(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCopierCard(BuildContext context) {
    const String mockAddress = 'addr1q8a72b100641de406d824855a782b13fa92c3ff';
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WALLET ADDRESS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  mockAddress,
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: mockAddress));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address copied to clipboard.')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredTransactions(ZeroPayRepository repository, String assetSymbol) {
    return FutureBuilder<List<Transaction>>(
      future: repository.getTransactions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final list = snapshot.data!.where((tx) => tx.assetSymbol.toUpperCase() == assetSymbol.toUpperCase()).toList();

        if (list.isEmpty) {
          return const BentoCard(
            child: Center(
              child: Text(
                'No ledger movements for this asset.',
                style: TextStyle(color: AppColors.outline, fontSize: 12),
              ),
            ),
          );
        }

        return Column(
          children: list.map((tx) {
            final isSend = tx.type == 'Send' || tx.type == 'Escrow Lock';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: BentoCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isSend ? AppColors.error.withOpacity(0.06) : AppColors.tertiary.withOpacity(0.06),
                      child: Icon(
                        isSend ? Icons.arrow_outward : Icons.call_received,
                        size: 14,
                        color: isSend ? AppColors.error : AppColors.tertiary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(
                            tx.txHash,
                            style: const TextStyle(color: AppColors.outline, fontSize: 10, fontFamily: 'monospace'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isSend ? '-' : '+'}${tx.amount} ${tx.assetSymbol}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSend ? AppColors.error : AppColors.tertiary,
                      ),
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

class SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color lineColor;

  SparklinePainter({required this.points, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [lineColor.withOpacity(0.2), lineColor.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final double widthSegment = size.width / (points.length - 1);
    final double max = points.reduce((a, b) => a > b ? a : b);
    final double min = points.reduce((a, b) => a < b ? a : b);
    final double range = max - min == 0 ? 1 : max - min;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final double x = i * widthSegment;
      // Invert Y coordinate since Canvas 0,0 is top-left
      final double y = size.height - ((points[i] - min) / range * size.height * 0.8) - (size.height * 0.1);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      
      if (i == points.length - 1) {
        fillPath.lineTo(x, size.height);
        fillPath.close();
      }
    }

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
