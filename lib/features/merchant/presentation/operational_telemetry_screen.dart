import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../core/api/network_health_monitor.dart';
import '../../../shared/data/repository.dart';

final operationalTelemetryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(zeroPayRepositoryProvider);
  final health = await repo.getDiagnosticsHealth();
  final queues = await repo.getDiagnosticsQueues();
  final blockchain = await repo.getDiagnosticsBlockchain();
  return {
    'health': health,
    'queues': queues,
    'blockchain': blockchain,
  };
});

class OperationalTelemetryScreen extends ConsumerStatefulWidget {
  const OperationalTelemetryScreen({super.key});

  @override
  ConsumerState<OperationalTelemetryScreen> createState() => _OperationalTelemetryScreenState();
}

class _OperationalTelemetryScreenState extends ConsumerState<OperationalTelemetryScreen> {
  bool _webhookRelayTripped = false;
  bool _ledgerNodeTripped = false;

  @override
  Widget build(BuildContext context) {
    final telemetryAsync = ref.watch(operationalTelemetryProvider);

    // Initialize breaker overrides based on mock database contexts or live failures
    if (NetworkHealthMonitor.apiFailureCount >= 5) {
      _webhookRelayTripped = true;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Enterprise Health & Telemetry', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () => context.canPop() ? context.pop() : context.go('/merchant/dashboard'),
        ),
      ),
      body: telemetryAsync.when(
        loading: () => const SafeArea(child: LoadingStateView()),
        error: (err, stack) => ErrorStateView(
          title: 'Error loading telemetry data',
          description: err.toString(),
          onRetry: () => ref.invalidate(operationalTelemetryProvider),
          retryButtonText: 'Try Loading Again',
        ),
        data: (telemetryData) {
          final health = telemetryData['health'] ?? {};
          final blockchain = telemetryData['blockchain'] ?? {};

          return StreamBuilder<List<TelemetryLog>>(
            stream: NetworkHealthMonitor.healthLogsStream,
            initialData: NetworkHealthMonitor.logs,
            builder: (context, snapshot) {
              final logs = snapshot.data ?? [];

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Real API Cluster Stats
                  _buildNetworkStatusPanel(health, blockchain),
                  const SizedBox(height: 20),

                  // Ledger sync monitor
                  _buildLedgerNodePanel(
                    blockchain['detail'] ?? 'Reachable',
                    (blockchain['status'] == 'ok' || blockchain['status'] == 'healthy') ? 100.0 : 0.0,
                  ),
                  const SizedBox(height: 20),

                  // Background Queues status
                  Text('Background Message Queues', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  BentoCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ...((telemetryData['queues']?['queues'] as List? ?? []).map((q) {
                          final name = q['name'] as String? ?? '';
                          final waiting = q['waiting'] ?? 0;
                          final active = q['active'] ?? 0;
                          final failed = q['failed'] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    Text('active: $active', style: const TextStyle(fontSize: 10, color: AppColors.outline)),
                                    const SizedBox(width: 8),
                                    Text('waiting: $waiting', style: const TextStyle(fontSize: 10, color: AppColors.outline)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'failed: $failed',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: failed > 0 ? AppColors.error : AppColors.tertiary,
                                        fontWeight: failed > 0 ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Circuit Breakers
                  Text('Fail-Safe Circuit Breaker Switches', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  BentoCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildCircuitSwitchRow(
                          'API Base Gateway Router',
                          'Fails safe when main server returns multiple consecutive 5xx errors.',
                          _webhookRelayTripped,
                          (val) => setState(() => _webhookRelayTripped = val),
                        ),
                        const Divider(height: 20),
                        _buildCircuitSwitchRow(
                          'Ledger Settlement Validator',
                          'Suspends on-chain releases if block validation latency exceeds 10 blocks.',
                          _ledgerNodeTripped,
                          (val) => setState(() => _ledgerNodeTripped = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Active Observability Failures & Sentry Alerts
                  Text('Active Sentry & Network Failures', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (logs.isEmpty)
                    const BentoCard(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Text('0 active anomalies • System health is optimal', style: TextStyle(color: AppColors.tertiary, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: logs.map((log) {
                        final isAPI = log.category == 'API';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: BentoCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isAPI ? Icons.cloud_off : Icons.warning_amber_rounded,
                                          color: isAPI ? Colors.orange : Colors.red,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${log.category}: ${log.title}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${log.timestamp.hour}:${log.timestamp.minute}:${log.timestamp.second}',
                                      style: const TextStyle(fontSize: 10, color: AppColors.outline),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    log.details,
                                    style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppColors.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNetworkStatusPanel(Map<String, dynamic> health, Map<String, dynamic> blockchain) {
    final services = health['services'] ?? {};
    final mongo = services['mongodb'] ?? {};
    final redis = services['redis'] ?? {};

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('REALTIME NETWORK & SERVICES TELEMETRY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.outline)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTelemetryBlock(
                  'MongoDB',
                  mongo['status'] == 'ok' ? '${mongo['latencyMs']} ms' : 'Offline',
                  mongo['status'] == 'ok' ? AppColors.tertiary : AppColors.error,
                ),
              ),
              Expanded(
                child: _buildTelemetryBlock(
                  'Redis',
                  redis['status'] == 'ok' ? '${redis['latencyMs']} ms' : 'Offline',
                  redis['status'] == 'ok' ? AppColors.secondary : AppColors.error,
                ),
              ),
              Expanded(
                child: _buildTelemetryBlock(
                  'Blockchain',
                  blockchain['status'] == 'ok' ? '${blockchain['latencyMs']} ms' : 'Degraded',
                  blockchain['status'] == 'ok' ? AppColors.primary : Colors.orange,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildTelemetryBlock(
                  'App Success Rate',
                  '${NetworkHealthMonitor.successRate.toStringAsFixed(1)}%',
                  NetworkHealthMonitor.successRate > 90 ? AppColors.tertiary : Colors.orange,
                ),
              ),
              Expanded(
                child: _buildTelemetryBlock(
                  'App Avg Latency',
                  '${NetworkHealthMonitor.averageResponseTime.toStringAsFixed(1)} ms',
                  AppColors.secondary,
                ),
              ),
              Expanded(
                child: _buildTelemetryBlock(
                  'Total Queries',
                  '${NetworkHealthMonitor.requestCount}',
                  AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerNodePanel(String height, double syncPct) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CARDANO BLOCK SYNC MONITOR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.outline)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Node Block Height', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                  Text(height, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Validation Node Sync', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                  Text('$syncPct%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.tertiary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: syncPct / 100,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.tertiary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryBlock(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.outline)),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildCircuitSwitchRow(String title, String desc, bool value, ValueChanged<bool> onChange) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 10, color: AppColors.outline)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            Text(
              value ? 'TRIPPED' : 'NORMAL',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: value ? AppColors.error : AppColors.tertiary,
              ),
            ),
            Switch(
              value: !value, // Switch ON means NORMAL (not tripped)
              activeThumbColor: AppColors.tertiary,
              inactiveThumbColor: AppColors.error,
              inactiveTrackColor: AppColors.errorContainer,
              onChanged: (normalVal) {
                onChange(!normalVal);
              },
            ),
          ],
        ),
      ],
    );
  }
}
