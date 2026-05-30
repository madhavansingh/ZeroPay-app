import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// State overrides for testing empty, loading, error, and offline UI variations
enum AppUiState { normal, loading, empty, error, offline }

final appUiStateProvider = StateProvider<AppUiState>((ref) => AppUiState.normal);

// Periodic Stream simulating real-time Cardano/Ledger price updates and asset valuations
final priceFeedProvider = StreamProvider.autoDispose<Map<String, double>>((ref) async* {
  final initialPrices = {'ADA': 0.40, 'USDC': 1.00, 'ETH': 3350.00};
  
  while (true) {
    await Future.delayed(const Duration(seconds: 8));
    // Simulate slight fluctuations
    initialPrices['ADA'] = (initialPrices['ADA']! + (DateTime.now().second % 2 == 0 ? 0.002 : -0.001));
    initialPrices['ETH'] = (initialPrices['ETH']! + (DateTime.now().second % 2 == 0 ? 4.5 : -3.2));
    yield initialPrices;
  }
});

// Real-time Event simulation model for smart contracts and dispute courts
class RealtimeEvent {
  final String title;
  final String message;
  final String type; // 'escrow', 'dispute', 'security', 'wallet'
  final DateTime timestamp;

  RealtimeEvent({
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
  });
}

// Periodic Stream simulating smart contract notifications (WebSocket/Firebase)
final realtimeEventProvider = StreamProvider.autoDispose<RealtimeEvent>((ref) async* {
  final events = [
    RealtimeEvent(
      title: 'Milestone Completed',
      message: 'Merchant submitted deliverables for Design Phase of Escrow #INV-9801.',
      type: 'escrow',
      timestamp: DateTime.now(),
    ),
    RealtimeEvent(
      title: 'USDC Locked in Contract',
      message: '1,500 USDC pre-funded lock confirmed on Arbitrum chain.',
      type: 'escrow',
      timestamp: DateTime.now(),
    ),
    RealtimeEvent(
      title: 'Arbitration Update',
      message: 'Consensus leaning shifted in Case #DS-9281. Click to view jury consensus.',
      type: 'dispute',
      timestamp: DateTime.now(),
    ),
    RealtimeEvent(
      title: 'Secure Enclave Verified',
      message: 'Device signature validated on-chain.',
      type: 'security',
      timestamp: DateTime.now(),
    ),
  ];

  int index = 0;
  while (true) {
    await Future.delayed(const Duration(seconds: 15));
    yield events[index % events.length];
    index++;
  }
});
