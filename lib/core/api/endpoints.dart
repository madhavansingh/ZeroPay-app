import 'version_manager.dart';

class ApiEndpoints {
  ApiEndpoints._();

  // Root endpoint configuration
  static String get baseUrl => ApiVersionManager.baseUrl;

  // Auth endpoints
  static const String authLogin = '/auth/login';
  static const String authKeyValidate = '/auth/keys/validate';
  static const String authVerifyToken = '/auth/session/verify';

  // Wallet & Ledger
  static const String walletBalances = '/wallet/balances';
  static const String walletTransactions = '/wallet/transactions';
  static const String walletSend = '/wallet/transfer';
  static const String ledgerHistory = '/ledger/history';

  // Escrow Engine
  static const String escrowCreate = '/escrow/contracts';
  static const String escrowList = '/escrow/contracts';
  static const String escrowReleaseMilestone = '/escrow/release-milestone';
  static const String escrowRaiseDispute = '/escrow/dispute';

  // Merchant Portal
  static const String merchantProfile = '/merchant/profile';
  static const String merchantListings = '/merchant/listings';
  static const String merchantRevenueStats = '/merchant/stats/revenue';
  static const String merchantPayouts = '/merchant/payouts';

  // AI Negotiation
  static const String aiNegotiateChat = '/ai/negotiation/chat';
  static const String aiAuditContract = '/ai/contract/audit';
  static const String aiRecommendations = '/ai/insights/recommendations';

  // Arbitration Court
  static const String courtDisputeCases = '/court/cases';
  static const String courtSubmitEvidence = '/court/evidence';
  static const String courtCastVote = '/court/vote';

  // Telemetry & Metrics
  static const String telemetryLogMetrics = '/telemetry/metrics';
  static const String telemetryLogEvents = '/telemetry/events';
}
