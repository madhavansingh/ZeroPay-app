import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'endpoints.dart';

// Riverpod Provider for Base Api Client
final apiClientProvider = Provider<BaseApiClient>((ref) {
  return BaseApiClient();
});

// ----------------------------------------------------
// Auth API Service
// ----------------------------------------------------
class AuthApiService {
  final BaseApiClient _client;
  AuthApiService(this._client);

  Future<Response> loginWithMnemonic(List<String> mnemonic) async {
    return await _client.post(
      ApiEndpoints.authLogin,
      data: {'mnemonic': mnemonic.join(' ')},
    );
  }

  Future<Response> validateKeyStatus(String publicKey) async {
    return await _client.post(
      ApiEndpoints.authKeyValidate,
      data: {'public_key': publicKey},
    );
  }

  Future<Response> getCurrentUser() async {
    return await _client.get('/auth/me');
  }

  Future<Response> syncFirebaseSession(String idToken) async {
    return await _client.post(
      '/auth/sync',
      options: Options(
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      ),
    );
  }

  Future<Response> updateProfile(Map<String, dynamic> data) async {
    return await _client.put(ApiEndpoints.authProfile, data: data);
  }

  Future<Response> switchRole(String role) async {
    return await _client.put(ApiEndpoints.authRole, data: {'role': role});
  }
}

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService(ref.read(apiClientProvider));
});

// ----------------------------------------------------
// Wallet API Service
// ----------------------------------------------------
class WalletApiService {
  final BaseApiClient _client;
  WalletApiService(this._client);

  Future<Response> fetchBalances() async {
    return await _client.get(ApiEndpoints.walletBalances);
  }

  Future<Response> fetchAdaInrRate() async {
    return await _client.get('/price/ada-inr');
  }

  Future<Response> fetchTransactionHistory() async {
    return await _client.get(ApiEndpoints.walletTransactions);
  }

  Future<Response> sendTransfer({
    required String recipientAddress,
    required double amount,
    required String tokenSymbol,
    String? mnemonic,
  }) async {
    return await _client.post(
      ApiEndpoints.walletSend,
      data: {
        'recipient': recipientAddress,
        'amount': amount,
        'symbol': tokenSymbol,
        if (mnemonic != null) 'mnemonic': mnemonic,
      },
    );
  }

  Future<Response> signTransaction({
    required String unsignedCbor,
    required List<String> mnemonic,
  }) async {
    return await _client.post(
      '/wallet/sign',
      data: {
        'unsignedCbor': unsignedCbor,
        'mnemonic': mnemonic.join(' '),
      },
    );
  }
}

final walletApiServiceProvider = Provider<WalletApiService>((ref) {
  return WalletApiService(ref.read(apiClientProvider));
});

// ----------------------------------------------------
// Escrow API Service
// ----------------------------------------------------
class EscrowApiService {
  final BaseApiClient _client;
  EscrowApiService(this._client);

  Future<Response> listContracts(String role) async {
    final path = role == 'merchant' ? ApiEndpoints.escrowMerchantList : ApiEndpoints.escrowCustomerList;
    return await _client.get(path);
  }

  Future<Response> getEscrowDetails(String invoiceId) async {
    return await _client.get('/invoices/$invoiceId');
  }

  Future<Response> createEscrowContract(Map<String, dynamic> contractData) async {
    return await _client.post(ApiEndpoints.escrowCreate, data: contractData);
  }

  Future<Response> triggerEscrowLock(String escrowId, String customerAddress) async {
    return await _client.post(
      '/escrow/$escrowId/lock',
      data: {
        'customerAddress': customerAddress,
      },
    );
  }

  Future<Response> submitEscrowLock(String escrowId, String txHash, String customerAddress) async {
    return await _client.post(
      '/escrow/$escrowId/lock/submit',
      data: {
        'txHash': txHash,
        'customerAddress': customerAddress,
      },
    );
  }

  Future<Response> triggerMilestoneRelease(String escrowId, String milestoneId, {String? customerAddress}) async {
    final path = ApiEndpoints.escrowReleaseMilestone.replaceFirst(':invoiceId', escrowId);
    return await _client.post(
      path,
      data: {
        'customerAddress': customerAddress ?? '',
        'milestone_id': milestoneId,
      },
    );
  }

  Future<Response> submitMilestoneRelease(String escrowId, String txHash, {int? payoutLovelace}) async {
    final path = '/escrow/$escrowId/release/submit';
    return await _client.post(
      path,
      data: {
        'txHash': txHash,
        'payoutLovelace': payoutLovelace ?? 2000000,
      },
    );
  }

  Future<Response> triggerEscrowDispute(String escrowId, {String? signerAddress}) async {
    final path = ApiEndpoints.escrowRaiseDispute.replaceFirst(':invoiceId', escrowId);
    return await _client.post(
      path,
      data: {
        'signerAddress': signerAddress ?? '',
      },
    );
  }

  Future<Response> submitEscrowDispute(String escrowId, String txHash) async {
    final path = '/escrow/$escrowId/dispute/submit';
    return await _client.post(
      path,
      data: {
        'txHash': txHash,
      },
    );
  }
}

final escrowApiServiceProvider = Provider<EscrowApiService>((ref) {
  return EscrowApiService(ref.read(apiClientProvider));
});

// ----------------------------------------------------
// Merchant API Service
// ----------------------------------------------------
class MerchantApiService {
  final BaseApiClient _client;
  MerchantApiService(this._client);

  Future<Response> getProfile() async {
    return await _client.get(ApiEndpoints.merchantProfile);
  }

  Future<Response> updateListingStatus(String listingId, bool isActive) async {
    return await _client.post(
      ApiEndpoints.merchantListings,
      data: {
        'listing_id': listingId,
        'is_active': isActive,
      },
    );
  }

  Future<Response> fetchRevenueMetrics() async {
    return await _client.get(ApiEndpoints.merchantRevenueStats);
  }

  Future<Response> getPayoutsList() async {
    return await _client.get(ApiEndpoints.merchantPayouts);
  }

  Future<Response> fetchRevenueSummary() async {
    return await _client.get('/analytics/merchant/summary');
  }

  Future<Response> fetchRevenueTimeline() async {
    return await _client.get('/analytics/merchant/revenue');
  }

  Future<Response> fetchMerchantInsights() async {
    return await _client.get('/analytics/merchant/insights');
  }

  Future<Response> fetchStorefrontCatalog(String slug) async {
    return await _client.get('/storefronts/$slug/catalog');
  }

  Future<Response> getMerchantStorefront(String slug) async {
    return await _client.get('/storefronts/$slug');
  }

  Future<Response> setupStorefront(Map<String, dynamic> data) async {
    return await _client.post('/storefronts/setup', data: data);
  }

  Future<Response> updateStorefront(Map<String, dynamic> data) async {
    return await _client.put('/storefronts/update', data: data);
  }

  Future<Response> createProduct(Map<String, dynamic> data) async {
    return await _client.post('/catalog/products', data: data);
  }

  Future<Response> deleteProduct(String id) async {
    return await _client.delete('/catalog/products/$id');
  }

  Future<Response> fetchMarketplaceFeed() async {
    return await _client.get('/marketplace/feed');
  }

  Future<Response> getMerchantDashboard() async {
    return await _client.get('/merchant/dashboard');
  }

  Future<Response> fetchInvoicesList() async {
    return await _client.get('/invoices/merchant/list');
  }

  Future<Response> fetchWebhookDeliveries() async {
    return await _client.get('/webhooks/deliveries');
  }
}

final merchantApiServiceProvider = Provider<MerchantApiService>((ref) {
  return MerchantApiService(ref.read(apiClientProvider));
});

// ----------------------------------------------------
// AI API Service
// ----------------------------------------------------
class AiApiService {
  final BaseApiClient _client;
  AiApiService(this._client);

  Future<Response> sendChatMessage(String roomId, String invoiceId, String message) async {
    final path = '/chat/rooms/$roomId/messages';
    return await _client.post(
      path,
      data: {
        'invoiceId': invoiceId,
        'message': message,
      },
    );
  }

  Future<Response> getChatRooms() async {
    return await _client.get('/chat/rooms');
  }

  Future<Response> getChatRoomDetails(String roomId) async {
    return await _client.get('/chat/rooms/$roomId');
  }

  Future<Response> createChatRoom(String merchantStringId) async {
    return await _client.post('/chat/rooms/create', data: {
      'merchantStringId': merchantStringId,
    });
  }

  Future<Response> generateMilestones(String description, int totalAmountPaise) async {
    return await _client.post(
      '/ai/milestones/generate',
      data: {
        'description': description,
        'totalAmountPaise': totalAmountPaise,
      },
    );
  }

  Future<Response> submitContractForAudit(String contractText) async {
    return await _client.post(
      ApiEndpoints.aiAuditContract,
      data: {'contract_text': contractText},
    );
  }

  Future<Response> getLuminaRecommendations() async {
    return await _client.get(ApiEndpoints.aiRecommendations);
  }
}

final aiApiServiceProvider = Provider<AiApiService>((ref) {
  return AiApiService(ref.read(apiClientProvider));
});

// ----------------------------------------------------
// Project API Service
// ----------------------------------------------------
class ProjectApiService {
  final BaseApiClient _client;
  ProjectApiService(this._client);

  Future<Response> generateProjectPlan({
    required String requirements,
    required int totalAmountPaise,
    String? customerId,
  }) async {
    return await _client.post(
      '/projects/plan',
      data: {
        'requirements': requirements,
        'totalAmountPaise': totalAmountPaise,
        if (customerId != null) 'customerId': customerId,
      },
    );
  }

  Future<Response> getLatestPlan(String planId) async {
    return await _client.get('/projects/plan/$planId');
  }

  Future<Response> getPlanVersions(String planId) async {
    return await _client.get('/projects/plan/$planId/versions');
  }

  Future<Response> getPlanVersion(String planId, int version) async {
    return await _client.get('/projects/plan/$planId/version/$version');
  }

  Future<Response> updatePlan(String planId, Map<String, dynamic> data) async {
    return await _client.put('/projects/plan/$planId', data: data);
  }

  Future<Response> regeneratePlan(String planId, {
    String? requirements,
    int? totalAmountPaise,
    String? customerId,
  }) async {
    return await _client.post(
      '/projects/plan/$planId/regenerate',
      data: {
        if (requirements != null) 'requirements': requirements,
        if (totalAmountPaise != null) 'totalAmountPaise': totalAmountPaise,
        if (customerId != null) 'customerId': customerId,
      },
    );
  }

  Future<Response> approvePlan(String planId, {String? network}) async {
    return await _client.post(
      '/projects/plan/$planId/approve',
      data: {
        if (network != null) 'network': network,
      },
    );
  }
}

final projectApiServiceProvider = Provider<ProjectApiService>((ref) {
  return ProjectApiService(ref.read(apiClientProvider));
});

// ----------------------------------------------------
// Court API Service
// ----------------------------------------------------
class CourtApiService {
  final BaseApiClient _client;
  CourtApiService(this._client);

  Future<Response> fetchCases() async {
    return await _client.get(ApiEndpoints.courtDisputeCases);
  }

  Future<Response> submitCourtEvidence(String caseId, String docHash) async {
    return await _client.post(
      ApiEndpoints.courtSubmitEvidence,
      data: {
        'case_id': caseId,
        'evidence_hash': docHash,
      },
    );
  }

  Future<Response> castConsensusVote(String caseId, bool supportPlaintiff) async {
    return await _client.post(
      ApiEndpoints.courtCastVote,
      data: {
        'case_id': caseId,
        'support_plaintiff': supportPlaintiff,
      },
    );
  }
}

final courtApiServiceProvider = Provider<CourtApiService>((ref) {
  return CourtApiService(ref.read(apiClientProvider));
});

// ----------------------------------------------------
// Telemetry & Metrics API Service
// ----------------------------------------------------
class TelemetryApiService {
  final BaseApiClient _client;
  TelemetryApiService(this._client);

  Future<void> logEvent(String name, Map<String, dynamic> params) async {
    try {
      await _client.post(
        ApiEndpoints.telemetryLogEvents,
        data: {
          'event_name': name,
          'parameters': params,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {
      // Fail silently in telemetry
    }
  }

  Future<void> logMetric(String metricName, double value) async {
    try {
      await _client.post(
        ApiEndpoints.telemetryLogMetrics,
        data: {
          'metric': metricName,
          'value': value,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {
      // Fail silently
    }
  }

  Future<Response> fetchQueuesHealth() async {
    return await _client.get('/health/queues');
  }

  Future<Response> fetchRedisHealth() async {
    return await _client.get('/health/redis');
  }

  Future<Response> fetchBlockchainHealth() async {
    return await _client.get('/health/blockchain');
  }

  Future<Response> fetchGeneralHealth() async {
    return await _client.get('/health');
  }
}

final telemetryApiServiceProvider = Provider<TelemetryApiService>((ref) {
  return TelemetryApiService(ref.read(apiClientProvider));
});

// ----------------------------------------------------
// GitHub Audit API Service
// ----------------------------------------------------
class GithubAuditApiService {
  final BaseApiClient _client;
  GithubAuditApiService(this._client);

  Future<Response> connectRepository({
    required String projectPlanId,
    required String repositoryUrl,
    String? branch,
  }) async {
    return await _client.post(
      '/github/connect',
      data: {
        'projectPlanId': projectPlanId,
        'repositoryUrl': repositoryUrl,
        if (branch != null) 'branch': branch,
      },
    );
  }

  Future<Response> triggerMilestoneAudit({
    required String projectPlanId,
    required String milestoneId,
  }) async {
    return await _client.post(
      '/github/audit',
      data: {
        'projectPlanId': projectPlanId,
        'milestoneId': milestoneId,
      },
    );
  }

  Future<Response> getAuditDetails(String auditId) async {
    return await _client.get('/github/audit/$auditId');
  }

  Future<Response> getProjectAudits(String projectPlanId) async {
    return await _client.get('/github/audit/project/$projectPlanId');
  }

  Future<Response> reverifyAudit(String auditId) async {
    return await _client.post('/github/audit/$auditId/reverify');
  }

  Future<Response> requestFixes(String auditId, String feedback) async {
    return await _client.post(
      '/github/audit/$auditId/request-fixes',
      data: {'feedback': feedback},
    );
  }

  Future<Response> getReleaseRecommendation(String auditId) async {
    return await _client.post('/github/audit/$auditId/release-recommendation');
  }
}

final githubAuditApiServiceProvider = Provider<GithubAuditApiService>((ref) {
  return GithubAuditApiService(ref.read(apiClientProvider));
});
