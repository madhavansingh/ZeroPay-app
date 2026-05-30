import 'package:flutter_riverpod/flutter_riverpod.dart';

class OfflineState {
  final bool isOffline;
  final int queuedActionsCount;

  OfflineState({
    required this.isOffline,
    required this.queuedActionsCount,
  });

  OfflineState copyWith({
    bool? isOffline,
    int? queuedActionsCount,
  }) {
    return OfflineState(
      isOffline: isOffline ?? this.isOffline,
      queuedActionsCount: queuedActionsCount ?? this.queuedActionsCount,
    );
  }
}

class OfflineNotifier extends StateNotifier<OfflineState> {
  OfflineNotifier() : super(OfflineState(isOffline: false, queuedActionsCount: 0));

  void toggleConnection() {
    state = state.copyWith(isOffline: !state.isOffline);
    if (!state.isOffline && state.queuedActionsCount > 0) {
      // Automatic re-sync when network returns
      syncQueue();
    }
  }

  void queueAction() {
    if (state.isOffline) {
      state = state.copyWith(queuedActionsCount: state.queuedActionsCount + 1);
    }
  }

  void syncQueue() {
    state = state.copyWith(queuedActionsCount: 0);
  }
}

final offlineProvider = StateNotifierProvider<OfflineNotifier, OfflineState>((ref) {
  return OfflineNotifier();
});
