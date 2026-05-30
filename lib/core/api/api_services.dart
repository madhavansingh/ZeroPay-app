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
    return await _client.post('/auth/sync', data: {'id_token': idToken});
  }

  Future<Response> updateProfile(Map<String, dynamic> data) async {
    return await _client.post('/auth/profile', data: data);
  }

  Future<Response> switchRole(String role) async {
    return await _client.post('/auth/role', data: {'role': role});
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

  Future<Response> fetchTransactionHistory() async {
    return await _client.get(ApiEndpoints.walletTransactions);
  }

  Future<Response> sendTransfer({
    required String recipientAddress,
    required double amount,
    required String tokenSymbol,
  }) async {
    return await _client.post(
      ApiEndpoints.walletSend,
      data: {
        'recipient': recipientAddress,
        'amount': amount,
        'symbol': tokenSymbol,
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

  Future<Response> listContracts() async {
    return await _client.get(ApiEndpoints.escrowList);
  }

  Future<Response> createEscrowContract(Map<String, dynamic> contractData) async {
    return await _client.post(ApiEndpoints.escrowCreate, data: contractData);
  }

  Future<Response> triggerMilestoneRelease(String escrowId, String milestoneId) async {
    return await _client.post(
      ApiEndpoints.escrowReleaseMilestone,
      data: {
        'escrow_id': escrowId,
        'milestone_id': milestoneId,
      },
    );
  }

  Future<Response> triggerEscrowDispute(String escrowId) async {
    return await _client.post(
      ApiEndpoints.escrowRaiseDispute,
      data: {'escrow_id': escrowId},
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

  Future<Response> sendChatMessage(String prompt, String contextId) async {
    return await _client.post(
      ApiEndpoints.aiNegotiateChat,
      data: {
        'prompt': prompt,
        'context_id': contextId,
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
