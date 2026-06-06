import 'version_manager.dart';

class ApiEndpoints {
  ApiEndpoints._();

  // Root endpoint configuration
  static String get baseUrl => ApiVersionManager.baseUrl;

  // Auth endpoints
  static const String authLogin = '/auth/login';
  static const String authKeyValidate = '/auth/keys/validate';
  static const String authVerifyToken = '/auth/session/verify';
  static const String authProfile = '/auth/profile';
  static const String authRole = '/auth/role';

  // Wallet & Ledger
  static const String walletBalances = '/wallet/balances';
  static const String walletTransactions = '/wallet/transactions';
  static const String walletSend = '/wallet/transfer';
  static const String ledgerHistory = '/ledger/history';

  // Escrow Engine
  static const String escrowCreate = '/invoices/create';
  static const String escrowMerchantList = '/invoices/merchant/list';
  static const String escrowCustomerList = '/invoices/customer/list';
  static const String escrowReleaseMilestone = '/escrow/:invoiceId/release';
  static const String escrowRaiseDispute = '/escrow/:invoiceId/dispute';

  // Merchant Portal
  static const String merchantProfile = '/merchant/profile';
  static const String merchantListings = '/merchant/listings';
  static const String merchantRevenueStats = '/merchant/stats/revenue';
  static const String merchantPayouts = '/merchant/payouts';

  // AI Negotiation & Chat
  static const String chatSendMessage = '/chat/rooms/:roomId/messages';
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
