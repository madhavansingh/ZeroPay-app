import 'dart:async';

class TelemetryLog {
  final String category; // 'API', 'Socket', 'Firebase', 'Provider'
  final String title;
  final String details;
  final DateTime timestamp;

  TelemetryLog({
    required this.category,
    required this.title,
    required this.details,
    required this.timestamp,
  });
}

class NetworkHealthMonitor {
  NetworkHealthMonitor._();

  static final List<TelemetryLog> _logs = [];
  static final _streamController = StreamController<List<TelemetryLog>>.broadcast();

  static Stream<List<TelemetryLog>> get healthLogsStream => _streamController.stream;
  static List<TelemetryLog> get logs => List.unmodifiable(_logs);

  static int apiSuccessCount = 0;
  static int apiFailureCount = 0;
  static double totalResponseTimeMs = 0;
  static int requestCount = 0;

  static void logSuccess(String apiPath, double responseTimeMs) {
    requestCount++;
    apiSuccessCount++;
    totalResponseTimeMs += responseTimeMs;
    _broadcast();
  }

  static void logFailure(String category, String title, [String? details]) {
    requestCount++;
    apiFailureCount++;
    final log = TelemetryLog(
      category: category,
      title: title,
      details: details ?? 'No additional information.',
      timestamp: DateTime.now(),
    );
    _logs.insert(0, log);
    if (_logs.length > 50) {
      _logs.removeLast(); // Cap size
    }
    _broadcast();
  }

  static void _broadcast() {
    _streamController.add(List.from(_logs));
  }

  static double get averageResponseTime => requestCount == 0 ? 0.0 : totalResponseTimeMs / requestCount;
  static double get successRate => requestCount == 0 ? 100.0 : (apiSuccessCount / requestCount) * 100.0;
}
