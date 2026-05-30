import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/models.dart' as domain;
import '../data/mock_data.dart';
import '../data/repository.dart';

enum DemoDataset {
  newUser,
  activeCustomer,
  activeMerchant,
  hybridPowerUser,
  smallMerchant,
  growingMerchant,
  enterpriseMerchant,
  marketplaceSeller,
  freelanceProject,
  agencyContract,
  marketplacePurchase,
  digitalService,
  disputedTransaction,
  enterpriseEscrow,
}

class DemoDatasetNotifier extends StateNotifier<DemoDataset> {
  DemoDatasetNotifier() : super(DemoDataset.hybridPowerUser);

  void setDataset(DemoDataset dataset) {
    state = dataset;
  }
}

final demoDatasetProvider = StateNotifierProvider<DemoDatasetNotifier, DemoDataset>((ref) {
  return DemoDatasetNotifier();
});

// ----------------------------------------------------
// Authentication State
// ----------------------------------------------------
class AuthState {
  final domain.User? user;
  final String currentRole; // 'customer' or 'merchant'
  final bool isLoading;
  final String? errorMessage;
  final bool otpSent;
  final String? phoneNumber;
  final bool isAuthenticated;
  final bool onboardingCompleted;

  AuthState({
    this.user,
    required this.currentRole,
    required this.isLoading,
    this.errorMessage,
    this.otpSent = false,
    this.phoneNumber,
    this.isAuthenticated = false,
    this.onboardingCompleted = false,
  });

  AuthState copyWith({
    domain.User? user,
    String? currentRole,
    bool? isLoading,
    String? errorMessage,
    bool? otpSent,
    String? phoneNumber,
    bool? isAuthenticated,
    bool? onboardingCompleted,
  }) {
    return AuthState(
      user: user ?? this.user,
      currentRole: currentRole ?? this.currentRole,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      otpSent: otpSent ?? this.otpSent,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(AuthState(currentRole: 'customer', isLoading: false)) {
    // Automatically update the user profile when the demo dataset changes
    _ref.listen<ZeroPayRepository>(zeroPayRepositoryProvider, (previous, next) {
      if (state.isAuthenticated) {
        _syncUserWithRepository();
      }
    });
    recoverSession();
  }

  Future<void> recoverSession() async {
    state = state.copyWith(isLoading: true);
    const storage = FlutterSecureStorage();
    try {
      final onboardingVal = await storage.read(key: 'onboarding_completed');
      final onboardingCompleted = onboardingVal == 'true';
      
      final authenticatedVal = await storage.read(key: 'is_authenticated');
      final isAuthenticated = authenticatedVal == 'true';
      
      final currentRole = await storage.read(key: 'selected_role') ?? 'customer';
      
      domain.User? user;
      if (isAuthenticated) {
        final repo = _ref.read(zeroPayRepositoryProvider);
        try {
          user = await repo.getCurrentUser();
          if (user.currentRole != currentRole) {
            user = await repo.switchRole(currentRole);
          }
        } catch (_) {
          // Secondary fallback to default safe profile
          user = domain.User(
            uid: 'usr_offline',
            email: 'offline.user@zeropay.io',
            name: 'Offline Explorer',
            currentRole: currentRole,
            biometricsEnabled: true,
            createdAt: DateTime.now(),
          );
        }
      }
      
      state = AuthState(
        user: user,
        currentRole: currentRole,
        isLoading: false,
        isAuthenticated: isAuthenticated,
        onboardingCompleted: onboardingCompleted,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> completeOnboarding() async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'onboarding_completed', value: 'true');
    state = state.copyWith(onboardingCompleted: true);
  }

  Future<void> _syncUserWithRepository() async {
    try {
      final repo = _ref.read(zeroPayRepositoryProvider);
      final user = await repo.getCurrentUser();
      state = state.copyWith(
        user: user,
        currentRole: user.currentRole,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> sendOTP(String phone) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate API call
    state = state.copyWith(
      isLoading: false,
      otpSent: true,
      phoneNumber: phone,
    );
  }

  Future<bool> verifyOTP(String code) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 600)); // Simulate verification
    if (code == '123456' || code.length == 6) {
      final repo = _ref.read(zeroPayRepositoryProvider);
      final user = await repo.getCurrentUser();
      
      const storage = FlutterSecureStorage();
      await storage.write(key: 'is_authenticated', value: 'true');
      await storage.write(key: 'onboarding_completed', value: 'true');
      await storage.write(key: 'selected_role', value: user.currentRole);

      state = AuthState(
        user: user,
        currentRole: user.currentRole,
        isLoading: false,
        isAuthenticated: true,
        onboardingCompleted: true,
        phoneNumber: state.phoneNumber,
      );
      return true;
    } else {
      state = state.copyWith(isLoading: false, errorMessage: 'Invalid verification code. Please check the code and try again.');
      return false;
    }
  }

  Future<void> signInWithSeedPhrase() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = _ref.read(zeroPayRepositoryProvider);
      final user = await repo.getCurrentUser();
      
      const storage = FlutterSecureStorage();
      await storage.write(key: 'is_authenticated', value: 'true');
      await storage.write(key: 'onboarding_completed', value: 'true');
      await storage.write(key: 'selected_role', value: user.currentRole);

      state = AuthState(
        user: user,
        currentRole: user.currentRole,
        isLoading: false,
        isAuthenticated: true,
        onboardingCompleted: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> signInBiometrically() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 400));
    final repo = _ref.read(zeroPayRepositoryProvider);
    final user = await repo.getCurrentUser();

    const storage = FlutterSecureStorage();
    await storage.write(key: 'is_authenticated', value: 'true');
    await storage.write(key: 'onboarding_completed', value: 'true');
    await storage.write(key: 'selected_role', value: user.currentRole);

    state = AuthState(
      user: user,
      currentRole: user.currentRole,
      isLoading: false,
      isAuthenticated: true,
      onboardingCompleted: true,
    );
  }

  Future<void> selectWorkspaceRole(String role) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = _ref.read(zeroPayRepositoryProvider);
      final updatedUser = await repo.switchRole(role);

      const storage = FlutterSecureStorage();
      await storage.write(key: 'selected_role', value: updatedUser.currentRole);

      state = state.copyWith(
        user: updatedUser,
        currentRole: updatedUser.currentRole,
        isLoading: false,
      );
    } catch (e) {
      final localUser = domain.User(
        uid: state.user?.uid ?? 'usr_offline',
        email: state.user?.email ?? 'offline.user@zeropay.io',
        name: state.user?.name ?? 'Offline Explorer',
        currentRole: role,
        biometricsEnabled: state.user?.biometricsEnabled ?? true,
        createdAt: state.user?.createdAt ?? DateTime.now(),
      );

      const storage = FlutterSecureStorage();
      await storage.write(key: 'selected_role', value: role);

      state = state.copyWith(
        user: localUser,
        currentRole: role,
        isLoading: false,
      );
    }
  }

  Future<void> switchWorkspaceRole() async {
    if (state.user == null) return;
    final newRole = state.currentRole == 'customer' ? 'merchant' : 'customer';
    await selectWorkspaceRole(newRole);
  }

  Future<void> signOut() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'is_authenticated');
    await storage.delete(key: 'selected_role');
    state = AuthState(
      currentRole: 'customer',
      isLoading: false,
      isAuthenticated: false,
      onboardingCompleted: state.onboardingCompleted,
    );
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    if (state.user == null) return;
    final updatedUser = state.user!.copyWith(biometricsEnabled: enabled);
    state = state.copyWith(user: updatedUser);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

// ----------------------------------------------------
// Theme State
// ----------------------------------------------------
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark); // Startup in premium dark mode by default

  void toggleTheme() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

// ----------------------------------------------------
// Notifications State
// ----------------------------------------------------
class NotificationNotifier extends StateNotifier<List<domain.Notification>> {
  NotificationNotifier() : super(MockData.notificationsList);

  void addNotification(domain.Notification notification) {
    state = [notification, ...state];
  }

  void markAsRead(String id) {
    state = state.map((n) {
      if (n.id == id) {
        return domain.Notification(
          id: n.id,
          title: n.title,
          description: n.description,
          category: n.category,
          timestamp: n.timestamp,
          isRead: true,
        );
      }
      return n;
    }).toList();
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, List<domain.Notification>>((ref) {
  return NotificationNotifier();
});

// ----------------------------------------------------
// App Session State (Biometrics and Locks)
// ----------------------------------------------------
class SessionState {
  final bool isLocked;
  final DateTime? lastActiveTime;

  SessionState({required this.isLocked, this.lastActiveTime});
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(SessionState(isLocked: false));

  void lockApp() {
    state = SessionState(isLocked: true, lastActiveTime: state.lastActiveTime);
  }

  void unlockApp() {
    state = SessionState(isLocked: false, lastActiveTime: DateTime.now());
  }

  void updateActiveTime() {
    state = SessionState(isLocked: false, lastActiveTime: DateTime.now());
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});

// ----------------------------------------------------
// Global Reactive Escrow Providers (Shared Source of Truth)
// ----------------------------------------------------

/// Customer escrow list — all customer screens must watch this provider.
/// Invalidate it after creating a new escrow to trigger refresh everywhere.
final customerEscrowsProvider = FutureProvider<List<domain.Escrow>>((ref) async {
  final repo = ref.watch(zeroPayRepositoryProvider);
  return repo.getEscrowContracts('customer');
});

/// Merchant escrow list — all merchant screens must watch this provider.
/// Invalidate it after creating a new escrow to trigger refresh everywhere.
final merchantEscrowsProvider = FutureProvider<List<domain.Escrow>>((ref) async {
  final repo = ref.watch(zeroPayRepositoryProvider);
  return repo.getEscrowContracts('merchant');
});

/// Combined escrow count for dashboard summary badges.
final escrowSummaryProvider = FutureProvider<Map<String, int>>((ref) async {
  final customerList = await ref.watch(customerEscrowsProvider.future);
  final merchantList = await ref.watch(merchantEscrowsProvider.future);
  final allIds = <String>{...customerList.map((e) => e.id), ...merchantList.map((e) => e.id)};
  final active = <String>{};
  final completed = <String>{};
  final disputed = <String>{};
  for (final e in [...customerList, ...merchantList]) {
    if (e.status == 'Locked' || e.status == 'Active' || e.status == 'Pending') {
      active.add(e.id);
    } else if (e.status == 'Released' || e.status == 'Completed') {
      completed.add(e.id);
    } else if (e.status == 'Disputed' || e.status == 'Resolved') {
      disputed.add(e.id);
    }
  }
  return {
    'total': allIds.length,
    'active': active.length,
    'completed': completed.length,
    'disputed': disputed.length,
  };
});

