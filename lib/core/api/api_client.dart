import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'endpoints.dart';
import 'network_health_monitor.dart';

class BaseApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  // Circuit Breaker State
  int _consecutiveFailures = 0;
  bool _isCircuitBroken = false;
  DateTime? _circuitBreakerTripTime;

  // Request Deduplication (Future cache-and-share)
  final Map<String, Future<Response>> _inFlightRequests = {};

  BaseApiClient({
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage() {
    _initClient();
  }

  void _initClient() {
    final existingBaseUrl = _dio.options.baseUrl;
    final existingConnectTimeout = _dio.options.connectTimeout;
    final existingReceiveTimeout = _dio.options.receiveTimeout;

    _dio.options = BaseOptions(
      baseUrl: existingBaseUrl.isNotEmpty ? existingBaseUrl : ApiEndpoints.baseUrl,
      connectTimeout: (existingConnectTimeout != null && existingConnectTimeout != Duration.zero)
          ? existingConnectTimeout
          : const Duration(seconds: 30),
      receiveTimeout: (existingReceiveTimeout != null && existingReceiveTimeout != Duration.zero)
          ? existingReceiveTimeout
          : const Duration(seconds: 120),
      contentType: 'application/json',
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Track session inactivity (Session Guard / Expiration check)
          final lastActiveStr = await _storage.read(key: 'session_last_active');
          if (lastActiveStr != null) {
            final lastActive = DateTime.parse(lastActiveStr);
            if (DateTime.now().difference(lastActive) > const Duration(minutes: 15)) {
              // Session expired, clear tokens
              await _storage.delete(key: 'auth_jwt_token');
              await _storage.delete(key: 'auth_refresh_token');
              NetworkHealthMonitor.logFailure('Provider', 'Session Expired', 'User session expired due to 15 minutes of inactivity.');
            }
          }
          await _storage.write(key: 'session_last_active', value: DateTime.now().toIso8601String());

          // Retrieve session JWT token from secure local keychain storage
          final token = await _storage.read(key: 'auth_jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            // Trigger token refresh strategy
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Retry original request
              final options = error.requestOptions;
              final retryResponse = await _dio.request(
                options.path,
                options: Options(
                  method: options.method,
                  headers: options.headers,
                ),
                data: options.data,
                queryParameters: options.queryParameters,
              );
              return handler.resolve(retryResponse);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'auth_refresh_token');
      if (refreshToken == null) return false;

      // Direct Refresh request using a clean instance of Dio to prevent loops
      final response = await Dio().post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.authVerifyToken}',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final newJwt = response.data['token'];
        final newRefresh = response.data['refresh_token'];
        await _storage.write(key: 'auth_jwt_token', value: newJwt);
        await _storage.write(key: 'auth_refresh_token', value: newRefresh);
        return true;
      }
    } catch (e) {
      // Refresh failed, purge token storage to force logout
      await _storage.delete(key: 'auth_jwt_token');
      await _storage.delete(key: 'auth_refresh_token');
      NetworkHealthMonitor.logFailure('API', 'Token Refresh Failed', e.toString());
    }
    return false;
  }

  // Deduplication & Circuit Breaker Guarded GET
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final dedupKey = 'GET:$path:${queryParameters?.toString()}';
    
    if (_inFlightRequests.containsKey(dedupKey)) {
      return _inFlightRequests[dedupKey]!;
    }

    final future = _executeWithResilience(() => _dio.get(
          path,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ),);
    _inFlightRequests[dedupKey] = future;

    try {
      return await future;
    } finally {
      _inFlightRequests.remove(dedupKey);
    }
  }

  // Deduplication & Circuit Breaker Guarded POST
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final dedupKey = 'POST:$path:${data?.toString()}:${queryParameters?.toString()}';
    
    if (_inFlightRequests.containsKey(dedupKey)) {
      return _inFlightRequests[dedupKey]!;
    }

    final future = _executeWithResilience(() => _dio.post(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ),);
    _inFlightRequests[dedupKey] = future;

    try {
      return await future;
    } finally {
      _inFlightRequests.remove(dedupKey);
    }
  }

  // Deduplication & Circuit Breaker Guarded PUT
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final dedupKey = 'PUT:$path:${data?.toString()}:${queryParameters?.toString()}';
    
    if (_inFlightRequests.containsKey(dedupKey)) {
      return _inFlightRequests[dedupKey]!;
    }

    final future = _executeWithResilience(() => _dio.put(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ),);
    _inFlightRequests[dedupKey] = future;

    try {
      return await future;
    } finally {
      _inFlightRequests.remove(dedupKey);
    }
  }

  // Deduplication & Circuit Breaker Guarded DELETE
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final dedupKey = 'DELETE:$path:${data?.toString()}:${queryParameters?.toString()}';
    
    if (_inFlightRequests.containsKey(dedupKey)) {
      return _inFlightRequests[dedupKey]!;
    }

    final future = _executeWithResilience(() => _dio.delete(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ),);
    _inFlightRequests[dedupKey] = future;

    try {
      return await future;
    } finally {
      _inFlightRequests.remove(dedupKey);
    }
  }

  // Resilience execution wrapper
  Future<Response> _executeWithResilience(Future<Response> Function() request) async {
    // 1. Check Circuit Breaker
    if (_isCircuitBroken && _circuitBreakerTripTime != null) {
      if (DateTime.now().difference(_circuitBreakerTripTime!) < const Duration(seconds: 30)) {
        throw Exception('Circuit breaker is active. Request blocked to prevent server overload.');
      } else {
        _isCircuitBroken = false; // Reset breaker
        _consecutiveFailures = 0;
      }
    }

    final stopwatch = Stopwatch()..start();
    int retries = 3;
    int delayMs = 1000;

    for (int i = 0; i < retries; i++) {
      try {
        final response = await request();
        stopwatch.stop();
        
        // Log telemetry success
        NetworkHealthMonitor.logSuccess(
          request.toString(),
          stopwatch.elapsedMilliseconds.toDouble(),
        );

        _consecutiveFailures = 0; // Reset count
        return response;
      } on DioException catch (e) {
        if (i == retries - 1) {
          stopwatch.stop();
          _consecutiveFailures++;
          
          if (_consecutiveFailures >= 5) {
            _isCircuitBroken = true;
            _circuitBreakerTripTime = DateTime.now();
            NetworkHealthMonitor.logFailure('API', 'Circuit Breaker Tripped', 'Circuit breaker tripped due to 5 consecutive API failures.');
          }

          NetworkHealthMonitor.logFailure('API', 'Request Failed (${e.response?.statusCode})', e.message);
          throw _handleError(e);
        }
        
        // Wait before retry (Exponential Backoff + Jitter)
        await Future.delayed(Duration(milliseconds: delayMs + (stopwatch.elapsedTicks % 200)));
        delayMs *= 2;
      }
    }
    throw Exception('Retry limits exceeded');
  }

  Exception _handleError(DioException error) {
    final message = error.response?.data?['message'] ?? error.message ?? 'An unknown network error occurred';
    return Exception(message);
  }
}
