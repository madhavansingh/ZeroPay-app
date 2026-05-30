import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../shared/data/repository.dart';
import '../api/network_health_monitor.dart';

class BackgroundSyncManager {
  final ZeroPayRepository _repository;
  Timer? _syncTimer;
  bool _isSyncing = false;

  BackgroundSyncManager(this._repository);

  // Start periodic background synchronization (e.g. every 60 seconds)
  void startSyncScheduler() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) => performSyncSweep());
    if (kDebugMode) {
      print('Background Sync Scheduler Mounted.');
    }
  }

  // Trigger sync sweep
  Future<void> performSyncSweep() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      if (kDebugMode) {
        print('Executing Background Synchronization Sweep...');
      }

      // 1. Sync Wallet & Settlement Ledgers
      await _repository.getWalletAssets();

      // 2. Sync Escrow Contracts
      await _repository.getEscrowContracts('customer');
      await _repository.getEscrowContracts('merchant');

      // 3. Sync Dispute consensus
      await _repository.getDisputeCase('DS-9281');

      // 4. Sync Webhooks & Ledgers
      await _repository.getLedgerHistory();
      await _repository.getWebhookHistory();

      if (kDebugMode) {
        print('Background Sync completed successfully.');
      }
    } catch (e) {
      NetworkHealthMonitor.logFailure(
        'Provider',
        'Background Sync Error',
        'Synchronization sweep failed to complete: ${e.toString()}',
      );
    } finally {
      _isSyncing = false;
    }
  }

  void stopSyncScheduler() {
    _syncTimer?.cancel();
  }
}
