import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/data/repository.dart';

class CourtDashboardScreen extends ConsumerStatefulWidget {
  const CourtDashboardScreen({super.key});

  @override
  ConsumerState<CourtDashboardScreen> createState() => _CourtDashboardScreenState();
}

class _CourtDashboardScreenState extends ConsumerState<CourtDashboardScreen> {
  DisputeCase? _disputeCase;
  bool _isLoading = true;
  String? _error;
  String? _userVote; // 'plaintiff' or 'defendant' or null

  @override
  void initState() {
    super.initState();
    _fetchDisputeDetails();
  }

  Future<void> _fetchDisputeDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      final caseData = await repo.getDisputeCase('DS-9281');
      setState(() {
        _disputeCase = caseData;
        _isLoading = false;
        // Check if user voted in mock state
        final userJurorIndex = caseData.jurors.indexWhere((j) => j.id == 'jr_6');
        if (userJurorIndex != -1 && caseData.jurors[userJurorIndex].hasVoted) {
          _userVote = 'voted';
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _castVote(bool favorPlaintiff) async {
    if (_disputeCase == null || _userVote != null) return;
    setState(() => _isLoading = true);
    
    final repo = ref.read(zeroPayRepositoryProvider);
    await repo.voteOnDispute(_disputeCase!.caseId, 'jr_6', favorPlaintiff);
    
    // Refresh case details
    final updatedCase = await repo.getDisputeCase(_disputeCase!.caseId);
    setState(() {
      _disputeCase = updatedCase;
      _userVote = favorPlaintiff ? 'plaintiff' : 'defendant';
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          favorPlaintiff
              ? 'Consensus vote submitted in favor of Plaintiff (Buyer).'
              : 'Consensus vote submitted in favor of Defendant (Seller).',
        ),
        backgroundColor: AppColors.tertiary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _disputeCase == null) {
      return const Scaffold(
        body: SafeArea(child: LoadingStateView()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Arbitration Peer Court', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
            onPressed: () => context.canPop() ? context.pop() : context.go('/customer/home'),
          ),
        ),
        body: ErrorStateView(
          title: 'Failed to load arbitration case',
          description: _error!,
          onRetry: _fetchDisputeDetails,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Arbitration Peer Court',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () => context.canPop() ? context.pop() : context.go('/customer/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _fetchDisputeDetails,
          ),
        ],
      ),
      body: _disputeCase == null
          ? EmptyStateView(
              icon: Icons.gavel_outlined,
              title: 'No active disputes',
              description: 'All escrow transactions are currently clear.',
              buttonText: 'View Workspace Dashboard',
              onButtonPressed: () => context.canPop() ? context.pop() : context.go('/customer/home'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCourtHeader(),
                  const SizedBox(height: 16),
                  if (_disputeCase != null) ...[
                    _buildCaseOverviewCard(),
                    const SizedBox(height: 16),
                    _buildConsensusGaugeCard(),
                    const SizedBox(height: 16),
                    _buildCaseTimelineCard(),
                    const SizedBox(height: 16),
                    _buildEvidenceCard(),
                    const SizedBox(height: 16),
                    _buildJurorsPanel(),
                    const SizedBox(height: 24),
                  ] else
                    _buildEmptyState(),
                ],
              ),
            ),
    );
  }

  Widget _buildCourtHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.08), AppColors.secondary.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Lumina Peer Consensus Protocol',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Decentralized dispute resolution. Real-world conflicts are adjudicated via peer validator pools. Vote results trigger automated smart contract settlements.',
            style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseOverviewCard() {
    final caseObj = _disputeCase!;
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'CASE ID: ${caseObj.caseId}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.primary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  caseObj.status.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            caseObj.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filing Date', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                  const SizedBox(height: 2),
                  Text(
                    '${caseObj.filingDate.day}/${caseObj.filingDate.month}/${caseObj.filingDate.year}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Disputed Escrow Fund', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                  const SizedBox(height: 2),
                  Text(
                    '\$${caseObj.disputedAmount.toStringAsFixed(2)} ${caseObj.assetSymbol}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsensusGaugeCard() {
    final caseObj = _disputeCase!;
    final leaning = caseObj.consensusLeaningCustomer; // plaintiff leaning %
    final leaningDefendant = 100.0 - leaning;

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Consensus Leaning Balance',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(
                painter: ConsensusGaugePainter(leaningPercentage: leaning),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Favor Plaintiff (Buyer)', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('${leaning.toStringAsFixed(0)}% Consensus', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Favor Defendant (Seller)', style: TextStyle(fontSize: 10, color: Colors.orange[800], fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('${leaningDefendant.toStringAsFixed(0)}% Consensus', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaseTimelineCard() {
    final caseObj = _disputeCase!;
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Argument & Testimony', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Divider(height: 24),
          _buildArgumentBubble(
            name: caseObj.plaintiffName,
            role: 'Plaintiff (Buyer)',
            text: 'Seller failed to deliver certified hardware on the expected date. USPS tracking indicates package was never received by courier, yet seller claims customs delay. On-chain audit proves escrow lock remains locked.',
            isPlaintiff: true,
          ),
          const SizedBox(height: 16),
          _buildArgumentBubble(
            name: caseObj.defendantName,
            role: 'Defendant (Seller)',
            text: 'Cargo logistics encountered unexpected export screening. Cargo manifest, customs clearance delay files, and freight documents have been submitted to peer court files for review.',
            isPlaintiff: false,
          ),
        ],
      ),
    );
  }

  Widget _buildArgumentBubble({
    required String name,
    required String role,
    required String text,
    required bool isPlaintiff,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlaintiff ? AppColors.primary.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
              Text(
                role,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isPlaintiff ? AppColors.primary : Colors.orange[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 11.5, height: 1.3, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard() {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Submitted Evidence Files', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
                onPressed: () {
                  context.go('/court/evidence-upload');
                },
              ),
            ],
          ),
          const Divider(height: 20),
          _buildEvidenceItem('USPS_Express_Freight_Manifest.pdf', 'Verified SHA-256 Hash', '0x2a8b...773f'),
          _buildEvidenceItem('Cardano_Escrow_Deploy_Parameters.json', 'Ledger Lock Receipt', 'Block #1938202'),
          _buildEvidenceItem('Merchant_Fulfillment_Manifest.pdf', 'Verified Cargo Receipt', '0x1c9d...9481'),
        ],
      ),
    );
  }

  Widget _buildEvidenceItem(String fileName, String description, String identifier) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                Text(description, style: const TextStyle(fontSize: 9, color: AppColors.outline)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              identifier,
              style: const TextStyle(fontSize: 8.5, fontFamily: 'monospace', color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJurorsPanel() {
    final caseObj = _disputeCase!;
    final pendingUserVote = _userVote == null;

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Validator Panel & Vote Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: caseObj.jurors.map((juror) {
              final hasVoted = juror.hasVoted || (juror.id == 'jr_6' && !pendingUserVote);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: hasVoted ? AppColors.tertiary.withValues(alpha: 0.06) : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasVoted ? AppColors.tertiary.withValues(alpha: 0.2) : AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasVoted ? Icons.check_circle : Icons.pending_actions,
                      size: 12,
                      color: hasVoted ? AppColors.tertiary : AppColors.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      juror.id == 'jr_6' ? '${juror.name} (YOU)' : juror.name,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hasVoted ? AppColors.tertiary : AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const Divider(height: 24),
          if (pendingUserVote) ...[
            const Center(
              child: Text(
                'YOUR VALIDATOR VOTE IS REQUIRED TO RESOLVE THIS CASE',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _castVote(true),
                    child: const Text(
                      'Vote Plaintiff',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange[850],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _castVote(false),
                    child: const Text(
                      'Vote Defendant',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.tertiary, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Your consensus vote has been cryptographically recorded.',
                      style: TextStyle(color: AppColors.tertiary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateView(
      icon: Icons.gavel_outlined,
      title: 'No active disputes',
      description: 'All escrow transactions are currently clear.',
      buttonText: 'View Workspace Dashboard',
      onButtonPressed: () => context.canPop() ? context.pop() : context.go('/customer/home'),
    );
  }
}

// Custom Painter for Peer consensus leaning scale sweep
class ConsensusGaugePainter extends CustomPainter {
  final double leaningPercentage; // e.g. 72.0 means 72% favor plaintiff
  ConsensusGaugePainter({required this.leaningPercentage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = size.height - 15;

    final paintBg = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final paintPlaintiff = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final paintDefendant = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // Draw semicircle arc from 180 degrees to 360 degrees (in radians, pi to 2*pi)
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, 3.14159, 3.14159, false, paintBg);

    // Calculate angles
    // Sweep angle is pi (180 degrees)
    // Plaintiff is leaningPercentage of 180 degrees
    final plaintiffSweep = (leaningPercentage / 100.0) * 3.14159;
    final defendantSweep = 3.14159 - plaintiffSweep;

    // Draw Plaintiff arc (starting from left, 180 degrees / pi)
    canvas.drawArc(rect, 3.14159, plaintiffSweep, false, paintPlaintiff);

    // Draw Defendant arc (starting from where plaintiff ends)
    canvas.drawArc(rect, 3.14159 + plaintiffSweep, defendantSweep, false, paintDefendant);

    // Draw center needle/indicator
    final needleAngle = 3.14159 + plaintiffSweep;
    final needlePaint = Paint()
      ..color = AppColors.onBackground
      ..style = PaintingStyle.fill;

    // Draw small hub at bottom center
    canvas.drawCircle(center, 8, needlePaint);

    final needleTip = Offset(
      center.dx + (radius - 12) * MathUtils.cos(needleAngle),
      center.dy + (radius - 12) * MathUtils.sin(needleAngle),
    );

    final needleStrokePaint = Paint()
      ..color = AppColors.onBackground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, needleTip, needleStrokePaint);
  }

  @override
  bool shouldRepaint(covariant ConsensusGaugePainter oldDelegate) {
    return oldDelegate.leaningPercentage != leaningPercentage;
  }
}

// Math utilities helper to avoid dart:math imports conflicting
class MathUtils {
  static double sin(double radians) {
    // Simple Taylor approximation or math library
    return _sinApprox(radians);
  }

  static double cos(double radians) {
    return _sinApprox(radians + 1.57079); // cos(x) = sin(x + pi/2)
  }

  static double _sinApprox(double x) {
    // clamp between -pi and pi
    double angle = x % 6.28318;
    if (angle > 3.14159) angle -= 6.28318;
    if (angle < -3.14159) angle += 6.28318;

    // Taylor series: x - x^3/6 + x^5/120 - x^7/5040
    final x3 = angle * angle * angle;
    final x5 = x3 * angle * angle;
    final x7 = x5 * angle * angle;
    return angle - (x3 / 6) + (x5 / 120) - (x7 / 5040);
  }
}
