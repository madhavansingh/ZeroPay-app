import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureCacheManager {
  final FlutterSecureStorage _storage;

  SecureCacheManager({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // Cache an object with a given key and custom TTL (in minutes)
  Future<void> cacheData(String key, Map<String, dynamic> data, {int ttlMinutes = 60}) async {
    final cachePayload = {
      'timestamp': DateTime.now().toIso8601String(),
      'ttl': ttlMinutes,
      'data': data,
    };
    await _storage.write(key: 'cache_$key', value: jsonEncode(cachePayload));
  }

  // Retrieve cached data if present and still valid
  Future<Map<String, dynamic>?> getCachedData(String key) async {
    try {
      final payloadStr = await _storage.read(key: 'cache_$key');
      if (payloadStr == null || payloadStr.isEmpty) return null;

      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      final timestamp = DateTime.parse(payload['timestamp'] as String);
      final ttl = payload['ttl'] as int;

      if (DateTime.now().difference(timestamp) > Duration(minutes: ttl)) {
        // Cache expired, wipe it
        await _storage.delete(key: 'cache_$key');
        return null;
      }

      return payload['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // Cache a list of objects
  Future<void> cacheList(String key, List<Map<String, dynamic>> list, {int ttlMinutes = 60}) async {
    final cachePayload = {
      'timestamp': DateTime.now().toIso8601String(),
      'ttl': ttlMinutes,
      'data': list,
    };
    await _storage.write(key: 'cache_list_$key', value: jsonEncode(cachePayload));
  }

  // Retrieve cached list
  Future<List<Map<String, dynamic>>?> getCachedList(String key) async {
    try {
      final payloadStr = await _storage.read(key: 'cache_list_$key');
      if (payloadStr == null || payloadStr.isEmpty) return null;

      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      final timestamp = DateTime.parse(payload['timestamp'] as String);
      final ttl = payload['ttl'] as int;

      if (DateTime.now().difference(timestamp) > Duration(minutes: ttl)) {
        await _storage.delete(key: 'cache_list_$key');
        return null;
      }

      final list = payload['data'] as List?;
      if (list == null) return null;

      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  // Purge all cache items
  Future<void> clearAllCache() async {
    final keys = await _storage.readAll();
    for (final key in keys.keys) {
      if (key.startsWith('cache_')) {
        await _storage.delete(key: key);
      }
    }
  }
}
