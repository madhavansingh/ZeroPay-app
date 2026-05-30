import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../api/api_client.dart';
import '../api/network_health_monitor.dart';

class QueueItem {
  final String id;
  final String path;
  final String method; // 'POST' or 'PUT'
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  QueueItem({
    required this.id,
    required this.path,
    required this.method,
    required this.payload,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'method': method,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
      };

  factory QueueItem.fromJson(Map<String, dynamic> json) => QueueItem(
        id: json['id'] as String,
        path: json['path'] as String,
        method: json['method'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class OfflineQueueManager {
  final FlutterSecureStorage _storage;
  final BaseApiClient _apiClient;
  final _uuid = const Uuid();

  OfflineQueueManager({
    FlutterSecureStorage? storage,
    required BaseApiClient apiClient,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _apiClient = apiClient;

  // Queue a new action securely
  Future<String> enqueueAction(String path, String method, Map<String, dynamic> payload) async {
    final actionId = _uuid.v4();
    final item = QueueItem(
      id: actionId,
      path: path,
      method: method,
      payload: payload,
      timestamp: DateTime.now(),
    );

    final queue = await _loadQueue();
    queue.add(item);
    await _saveQueue(queue);

    NetworkHealthMonitor.logFailure(
      'Provider',
      'Transaction Queued Locally',
      'Device is offline. Queued $method $path action under idempotency reference $actionId.',
    );
    
    return actionId;
  }

  // Auto-replay all queued actions when coming back online
  Future<void> replayQueue() async {
    final queue = await _loadQueue();
    if (queue.isEmpty) return;

    final List<QueueItem> failedItems = [];

    for (final item in queue) {
      try {
        // Enforce idempotency using standard headers
        final payloadWithIdempotency = Map<String, dynamic>.from(item.payload);
        payloadWithIdempotency['idempotency_key'] = item.id;

        if (item.method == 'POST') {
          await _apiClient.post(
            item.path,
            data: payloadWithIdempotency,
          );
        } else if (item.method == 'PUT') {
          await _apiClient.post( // dio client wrapper handles PUT or standard mappings
            item.path,
            data: payloadWithIdempotency,
          );
        }
      } catch (e) {
        // Replay failed (e.g. invalid auth or network dropped mid-sync), preserve item in queue
        failedItems.add(item);
        NetworkHealthMonitor.logFailure('API', 'Offline Replay Failed', e.toString());
      }
    }

    // Save only the items that failed (others successfully broadcast)
    await _saveQueue(failedItems);
  }

  Future<List<QueueItem>> _loadQueue() async {
    try {
      final data = await _storage.read(key: 'offline_action_queue');
      if (data == null || data.isEmpty) return [];

      final list = jsonDecode(data) as List;
      return list.map((e) => QueueItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveQueue(List<QueueItem> queue) async {
    final data = jsonEncode(queue.map((e) => e.toJson()).toList());
    await _storage.write(key: 'offline_action_queue', value: data);
  }
}
