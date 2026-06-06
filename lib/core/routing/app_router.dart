import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/global_providers.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/role_selection_screen.dart';
import '../../features/customer/presentation/customer_home_screen.dart';
import '../../features/customer/presentation/marketplace_screen.dart';
import '../../features/customer/presentation/merchant_profile_screen.dart' as customer_view;
import '../../features/customer/presentation/wallet_home_screen.dart';
import '../../features/customer/presentation/asset_details_screen.dart';
import '../../features/customer/presentation/send_tokens_screen.dart';
import '../../features/customer/presentation/receive_tokens_screen.dart';
import '../../features/customer/presentation/escrow_list_screen.dart';
import '../../features/customer/presentation/escrow_details_screen.dart';
import '../../features/customer/presentation/customer_profile_screen.dart';
import '../../shared/presentation/layout_shells.dart';

import '../../features/merchant/presentation/merchant_home_screen.dart';
import '../../features/merchant/presentation/storefront_management_screen.dart';
import '../../features/merchant/presentation/escrow_operations_screen.dart';
import '../../features/merchant/presentation/revenue_analytics_screen.dart';
import '../../features/merchant/presentation/merchant_profile_screen.dart' as merchant_view;
import '../../features/merchant/presentation/merchant_hq_screen.dart';
import '../../features/merchant/presentation/reputation_crm_screen.dart';
import '../../features/merchant/presentation/payout_center_screen.dart';
import '../../features/merchant/presentation/ai_business_intel_screen.dart';
import '../../features/merchant/presentation/operational_telemetry_screen.dart';

import '../../features/chat/presentation/commerce_chat_screen.dart';
import '../../features/ai/presentation/ai_negotiation_workspace.dart';
import '../../features/ai/presentation/contract_analysis_screen.dart';
import '../../features/escrow/presentation/escrow_builder_screen.dart';
import '../../features/court/presentation/court_dashboard_screen.dart';
import '../../features/court/presentation/evidence_upload_screen.dart';
import '../../features/trust/presentation/trust_risk_dashboard.dart';
import '../../features/auth/presentation/security_center_screen.dart';
import '../../features/splash/presentation/app_store_assets_screen.dart';

// Router Transition Notifier to listen to auth state changes and notify GoRouter
// without recreating the GoRouter instance.
class RouterTransitionNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterTransitionNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        if (previous?.isAuthenticated != next.isAuthenticated ||
            previous?.currentRole != next.currentRole) {
          notifyListeners();
        }
      },
    );
  }
}

final routerTransitionProvider = Provider<RouterTransitionNotifier>((ref) {
  return RouterTransitionNotifier(ref);
});

// Router config provider
final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ref.read(routerTransitionProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: listenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      final isLoggingIn = state.uri.path == '/auth';
      final isOnboarding = state.uri.path == '/onboarding';
      final isSplash = state.uri.path == '/splash';
      final isLoggedIn = authState.isAuthenticated;

      // 1. Splash redirection
      if (isSplash) {
        return null;
      }

      // 2. Auth guard: Unauthenticated users are redirected to onboarding (or auth if onboarding is completed)
      if (!isLoggedIn && !isLoggingIn && !isOnboarding) {
        if (authState.onboardingCompleted) {
          return '/auth';
        }
        return '/onboarding';
      }

      // 3. Authenticated users are prevented from visiting auth/onboarding
      if (isLoggedIn && (isLoggingIn || isOnboarding)) {
        return '/role-selection';
      }

      // Merchant home redirect alias
      if (state.uri.path == '/merchant/home') {
        return '/merchant/dashboard';
      }

      // 4. Role protection guard
      final isCustomerRoute = state.uri.path.startsWith('/customer');
      final isMerchantRoute = state.uri.path.startsWith('/merchant');
      final currentRole = authState.currentRole;

      if (isLoggedIn) {
        if (isCustomerRoute && currentRole != 'customer') {
          return '/merchant/dashboard';
        }
        if (isMerchantRoute && currentRole != 'merchant') {
          return '/customer/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      
      // Full screen Customer sub-routes (without bottom bar)
      GoRoute(
        path: '/customer/marketplace/merchant/:id',
        builder: (context, state) => customer_view.MerchantProfileScreen(merchantId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/customer/wallet/asset/:symbol',
        builder: (context, state) => AssetDetailsScreen(symbol: state.pathParameters['symbol'] ?? ''),
      ),
      GoRoute(
        path: '/customer/wallet/send',
        builder: (context, state) {
          final address = state.uri.queryParameters['address'];
          final amount = state.uri.queryParameters['amount'];
          final symbol = state.uri.queryParameters['symbol'];
          final title = state.uri.queryParameters['title'];
          final escrowId = state.uri.queryParameters['escrowId'];
          final merchantId = state.uri.queryParameters['merchantId'];
          final merchantName = state.uri.queryParameters['merchantName'];
          return SendTokensScreen(
            prefillAddress: address,
            prefillAmount: amount,
            prefillSymbol: symbol,
            prefillTitle: title,
            prefillEscrowId: escrowId,
            prefillMerchantId: merchantId,
            prefillMerchantName: merchantName,
          );
        },
      ),
      GoRoute(
        path: '/customer/wallet/receive',
        builder: (context, state) => const ReceiveTokensScreen(),
      ),
      GoRoute(
        path: '/customer/escrow/:id',
        builder: (context, state) => EscrowDetailsScreen(escrowId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/merchant/hq',
        builder: (context, state) => const MerchantHqScreen(),
      ),
      GoRoute(
        path: '/merchant/reputation',
        builder: (context, state) => const ReputationCrmScreen(),
      ),
      GoRoute(
        path: '/merchant/payout',
        builder: (context, state) => const PayoutCenterScreen(),
      ),
      GoRoute(
        path: '/merchant/insights',
        builder: (context, state) => const AiBusinessIntelScreen(),
      ),
      GoRoute(
        path: '/merchant/telemetry',
        builder: (context, state) => const OperationalTelemetryScreen(),
      ),
      GoRoute(
        path: '/customer/chat',
        builder: (context, state) {
          final threadId = state.uri.queryParameters['threadId'];
          final invoiceId = state.uri.queryParameters['invoiceId'];
          return CommerceChatScreen(
            preselectedThreadId: threadId,
            preselectedInvoiceId: invoiceId,
          );
        },
      ),
      GoRoute(
        path: '/ai/negotiation',
        builder: (context, state) => const AiNegotiationWorkspace(),
      ),
      GoRoute(
        path: '/ai/contract-analysis',
        builder: (context, state) => const ContractAnalysisScreen(),
      ),
      GoRoute(
        path: '/escrow/builder',
        builder: (context, state) => const EscrowBuilderScreen(),
      ),
      GoRoute(
        path: '/court/dashboard',
        builder: (context, state) => const CourtDashboardScreen(),
      ),
      GoRoute(
        path: '/court/evidence-upload',
        builder: (context, state) => const EvidenceUploadScreen(),
      ),
      GoRoute(
        path: '/trust/dashboard',
        builder: (context, state) => const TrustRiskDashboard(),
      ),
      GoRoute(
        path: '/security-center',
        builder: (context, state) => const SecurityCenterScreen(),
      ),
      GoRoute(
        path: '/onboarding/assets',
        builder: (context, state) => const AppStoreAssetsScreen(),
      ),

      // Customer Shell routes (with bottom bar navigation)
      ShellRoute(
        builder: (context, state, child) => CustomerShellLayout(child: child),
        routes: [
          GoRoute(
            path: '/customer/home',
            builder: (context, state) => const CustomerHomeScreen(),
          ),
          GoRoute(
            path: '/customer/marketplace',
            builder: (context, state) => const MarketplaceScreen(),
          ),
          GoRoute(
            path: '/customer/escrow',
            builder: (context, state) => const EscrowListScreen(),
          ),
          GoRoute(
            path: '/customer/wallet',
            builder: (context, state) => const WalletHomeScreen(),
          ),
          GoRoute(
            path: '/customer/profile',
            builder: (context, state) => const CustomerProfileScreen(),
          ),
        ],
      ),

      // Merchant Shell routes (with bottom bar navigation)
      ShellRoute(
        builder: (context, state, child) => MerchantShellLayout(child: child),
        routes: [
          GoRoute(
            path: '/merchant/dashboard',
            builder: (context, state) => const MerchantHomeScreen(),
          ),
          GoRoute(
            path: '/merchant/store',
            builder: (context, state) => const StorefrontManagementScreen(),
          ),
          GoRoute(
            path: '/merchant/escrows',
            builder: (context, state) => const EscrowOperationsScreen(),
          ),
          GoRoute(
            path: '/merchant/analytics',
            builder: (context, state) => const RevenueAnalyticsScreen(),
          ),
          GoRoute(
            path: '/merchant/profile',
            builder: (context, state) => const merchant_view.MerchantProfileScreen(),
          ),
        ],
      ),
    ],
  );
});
