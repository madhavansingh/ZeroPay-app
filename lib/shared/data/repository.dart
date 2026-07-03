import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models.dart';
import '../providers/global_providers.dart' show ScenarioProfile, scenarioProfileProvider;
import '../../core/api/api_services.dart';
import '../../core/security/secure_cache.dart';
import '../../core/offline/offline_manager.dart';
import 'intelligent_data_engine.dart';

// Interface
abstract class ZeroPayRepository {
  // Auth
  Future<User> getCurrentUser();
  Future<User> switchRole(String role);
  Future<User> setBiometricsEnabled(bool enabled);

  // Wallet
  Future<List<Asset>> getWalletAssets();
  Future<List<Transaction>> getTransactions();
  Future<void> sendTokens(String address, double amount, String symbol);

  // Escrow
  Future<List<Escrow>> getEscrowContracts(String role);
  Future<Escrow> getEscrowDetails(String id);
  Future<void> releaseMilestone(String escrowId, String milestoneId);
  Future<void> raiseDispute(String escrowId);
  Future<String> createEscrow(Escrow escrow);

  // Dispute & Court
  Future<DisputeCase> getDisputeCase(String caseId);
  Future<void> voteOnDispute(String caseId, String voterId, bool favorPlaintiff);
  Future<void> submitEvidence(String caseId, String description);

  // AI & Analytics
  Future<List<AIRecommendation>> getAIRecommendations();
  Future<List<ChatMessage>> getNegotiationChat();
  Future<List<Milestone>> generateMilestones(String description, double totalAmount, String assetSymbol);
  Future<void> sendChatMessage(String roomId, String invoiceId, String message);
  Future<List<Map<String, dynamic>>> getChatRooms();
  Future<Map<String, dynamic>> getChatRoomDetails(String roomId);
  Future<Map<String, dynamic>> createChatRoom(String merchantStringId);
  Future<List<LedgerEntry>> getLedgerHistory();
  Future<List<WebhookDelivery>> getWebhookHistory();

  // Extended Analytics
  Future<Map<String, dynamic>> getMerchantAnalyticsSummary(int windowDays);
  Future<Map<String, dynamic>> getMerchantRevenueTimeline(int windowDays);
  Future<Map<String, dynamic>> getMerchantInsights(int windowDays);

  // Extended Telemetry
  Future<Map<String, dynamic>> getDiagnosticsQueues();
  Future<Map<String, dynamic>> getDiagnosticsHealth();
  Future<Map<String, dynamic>> getDiagnosticsRedis();
  Future<Map<String, dynamic>> getDiagnosticsBlockchain();

  // Storefronts & Products
  Future<Map<String, dynamic>> getMerchantStorefront(String slug);
  Future<List<Map<String, dynamic>>> getStorefrontCatalog(String slug);
  Future<Map<String, dynamic>> setupStorefront(Map<String, dynamic> setupData);
  Future<Map<String, dynamic>> updateStorefront(Map<String, dynamic> updateData);
  Future<Map<String, dynamic>> createCatalogProduct(Map<String, dynamic> productData);
  Future<void> deleteCatalogProduct(String id);

  // Marketplace & Feed
  Future<Map<String, dynamic>> getMarketplaceFeed();

  // Dashboard & Invoices
  Future<Map<String, dynamic>> getMerchantDashboard();
  Future<Map<String, dynamic>> getInvoicesList({int page, int limit, String? status});

  // AI Project Planning
  Future<ProjectPlan> generateProjectPlan({
    required String requirements,
    required int totalAmountPaise,
    String? customerId,
    String? templateName,
    bool? generateAI,
  });
  Future<ProjectPlan> getLatestProjectPlan(String planId);
  Future<List<ProjectPlan>> getProjectPlanVersions(String planId);
  Future<ProjectPlan> getProjectPlanVersion(String planId, int version);
  Future<ProjectPlan> updateProjectPlan(String planId, Map<String, dynamic> data);
  Future<ProjectPlan> regenerateProjectPlan(String planId, {String? requirements, int? totalAmountPaise, String? customerId});
  Future<Map<String, dynamic>> approveProjectPlan(String planId, {String? network});

  // GitHub Auditing
  Future<Map<String, dynamic>> connectGitHubRepository({required String projectPlanId, required String repositoryUrl, String? branch});
  Future<Map<String, dynamic>> triggerMilestoneAudit({required String projectPlanId, required String milestoneId});
  Future<Map<String, dynamic>> getGitHubAuditDetails(String auditId);
  Future<List<dynamic>> getProjectGitHubAudits(String projectPlanId);
  Future<Map<String, dynamic>> reverifyGitHubAudit(String auditId);
  Future<Map<String, dynamic>> requestGitHubFixes(String auditId, String feedback);
  Future<Map<String, dynamic>> getGitHubReleaseRecommendation(String auditId);
}

// Runtime Implementation
class RuntimeRepository implements ZeroPayRepository {
  final ScenarioProfile dataset;
  final IntelligentDataEngine _demoData = IntelligentDataEngine();

  RuntimeRepository(this.dataset) {
    _demoData.setProfile(dataset);
  }

  // Auth
  @override
  Future<User> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _demoData.currentUser;
  }

  @override
  Future<User> switchRole(String role) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final updated = _demoData.currentUser.copyWith(currentRole: role);
    _demoData.updateUser(updated);
    return updated;
  }

  @override
  Future<User> setBiometricsEnabled(bool enabled) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final updated = _demoData.currentUser.copyWith(biometricsEnabled: enabled);
    _demoData.updateUser(updated);
    return updated;
  }

  // Wallet
  @override
  Future<List<Asset>> getWalletAssets() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _demoData.assets;
  }

  @override
  Future<List<Transaction>> getTransactions() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _demoData.transactions;
  }

  @override
  Future<void> sendTokens(String address, double amount, String symbol) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _demoData.deductWalletBalance(amount, symbol);
    _demoData.addTransaction(
      Transaction(
        txHash: '0x${DateTime.now().millisecondsSinceEpoch}',
        type: 'Send',
        assetSymbol: symbol,
        amount: amount,
        counterpartyAddress: address,
        timestamp: DateTime.now(),
        status: 'Confirmed',
      ),
    );
  }

  // Escrow
  @override
  Future<List<Escrow>> getEscrowContracts(String role) async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (role == 'customer') {
      return _demoData.escrows.where((element) => element.id != 'ZP-8842').toList();
    } else {
      return _demoData.escrows.where((element) => element.id != 'INV-9801').toList();
    }
  }

  @override
  Future<Escrow> getEscrowDetails(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _demoData.escrows.firstWhere(
      (element) => element.id == id,
      orElse: () => Escrow(
        id: id,
        title: 'Project Escrow',
        counterpartyAddress: 'addr1_counterparty',
        counterpartyName: 'Counterparty',
        totalValue: 100.0,
        assetSymbol: 'USDC',
        status: 'Locked',
        contractAddress: 'addr1_contract_$id',
        chainName: 'Cardano Testnet',
        createdAt: DateTime.now(),
        milestones: [],
      ),
    );
  }

  @override
  Future<void> releaseMilestone(String escrowId, String milestoneId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _demoData.releaseMilestone(escrowId, milestoneId);
  }

  @override
  Future<void> raiseDispute(String escrowId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _demoData.updateEscrowStatus(escrowId, 'Disputed');
  }

  @override
  Future<String> createEscrow(Escrow escrow) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _demoData.addEscrow(escrow);
    _demoData.deductWalletBalance(escrow.totalValue, escrow.assetSymbol);
    final txHash = '0x${DateTime.now().millisecondsSinceEpoch}';
    _demoData.addTransaction(
      Transaction(
        txHash: txHash,
        type: 'Escrow Lock',
        assetSymbol: escrow.assetSymbol,
        amount: escrow.totalValue,
        counterpartyAddress: escrow.counterpartyName,
        timestamp: DateTime.now(),
        status: 'Confirmed',
      ),
    );
    return txHash;
  }

  // Dispute & Court
  @override
  Future<DisputeCase> getDisputeCase(String caseId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _demoData.disputeCase;
  }

  @override
  Future<void> voteOnDispute(String caseId, String voterId, bool favorPlaintiff) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final updatedJurors = _demoData.disputeCase.jurors.map((e) {
      if (e.id == voterId) {
        return Juror(id: e.id, name: e.name, status: 'Voted', hasVoted: true);
      }
      return e;
    }).toList();

    final currentLeaning = _demoData.disputeCase.consensusLeaningCustomer;
    final newLeaning = favorPlaintiff ? currentLeaning + 5.0 : currentLeaning - 5.0;

    _demoData.updateDisputeCase(DisputeCase(
      caseId: _demoData.disputeCase.caseId,
      title: _demoData.disputeCase.title,
      disputedAmount: _demoData.disputeCase.disputedAmount,
      assetSymbol: _demoData.disputeCase.assetSymbol,
      plaintiffName: _demoData.disputeCase.plaintiffName,
      defendantName: _demoData.disputeCase.defendantName,
      status: _demoData.disputeCase.status,
      filingDate: _demoData.disputeCase.filingDate,
      consensusLeaningCustomer: newLeaning.clamp(0.0, 100.0),
      jurors: updatedJurors,
    ));
  }

  @override
  Future<void> submitEvidence(String caseId, String description) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _demoData.updateDisputeCase(DisputeCase(
      caseId: _demoData.disputeCase.caseId,
      title: _demoData.disputeCase.title,
      disputedAmount: _demoData.disputeCase.disputedAmount,
      assetSymbol: _demoData.disputeCase.assetSymbol,
      plaintiffName: _demoData.disputeCase.plaintiffName,
      defendantName: _demoData.disputeCase.defendantName,
      status: 'Deliberation',
      filingDate: _demoData.disputeCase.filingDate,
      consensusLeaningCustomer: _demoData.disputeCase.consensusLeaningCustomer + 2.0,
      jurors: _demoData.disputeCase.jurors,
    ));
  }

  // AI & Analytics
  @override
  Future<List<AIRecommendation>> getAIRecommendations() async {
    return _demoData.aiRecommendations;
  }

  @override
  Future<List<ChatMessage>> getNegotiationChat() async {
    return _demoData.chatMessages;
  }

  @override
  Future<List<Milestone>> generateMilestones(String description, double totalAmount, String assetSymbol) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return [
      Milestone(id: 'ms_comp_1', title: 'Phase 1: Foundation', description: 'Design assets, setup repositories, and basic wireframes.', amount: totalAmount * 0.3, status: 'Pending'),
      Milestone(id: 'ms_comp_2', title: 'Phase 2: Core Development', description: 'Complete primary visual screens and backend API syncing.', amount: totalAmount * 0.5, status: 'Pending'),
      Milestone(id: 'ms_comp_3', title: 'Phase 3: Security & Deployment', description: 'Conduct security code audits and release final app bundle.', amount: totalAmount * 0.2, status: 'Pending'),
    ];
  }

  @override
  Future<void> sendChatMessage(String roomId, String invoiceId, String message) async {
    await Future.delayed(const Duration(milliseconds: 50));
    _demoData.addChatMessage(
      ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        text: message,
        timestamp: DateTime.now(),
        sender: 'user',
        isAIHelper: false,
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getChatRooms() async {
    return [
      {
        'roomId': 'room_cryptobrews_789',
        'merchantId': 'mer_cryptobrews_789',
        'merchantName': 'CryptoBrews Coffee',
        'lastMessage': _demoData.chatMessages.isNotEmpty ? _demoData.chatMessages.last.text : 'No messages yet.',
        'unreadCount': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      }
    ];
  }

  @override
  Future<Map<String, dynamic>> getChatRoomDetails(String roomId) async {
    return {
      'roomId': roomId,
      'messages': _demoData.chatMessages.map((m) => {
        'id': m.id,
        'text': m.text,
        'timestamp': m.timestamp.toIso8601String(),
        'sender': m.sender,
        'isAIHelper': m.isAIHelper,
      }).toList(),
    };
  }

  @override
  Future<Map<String, dynamic>> createChatRoom(String merchantStringId) async {
    return {
      'roomId': 'room_$merchantStringId',
      'merchantId': merchantStringId,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<List<LedgerEntry>> getLedgerHistory() async {
    return _demoData.ledgerHistory;
  }

  @override
  Future<List<WebhookDelivery>> getWebhookHistory() async {
    return _demoData.webhookHistory;
  }

  // Extended Analytics
  @override
  Future<Map<String, dynamic>> getMerchantAnalyticsSummary(int windowDays) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return {
      'totalVolumePaise': 3245000.0,
      'totalVolumeLovelace': 45230500000.0,
      'averageSettlementTime': 1.8,
      'retentionRate': 86.5,
      'conversionRate': 4.1,
    };
  }

  @override
  Future<Map<String, dynamic>> getMerchantRevenueTimeline(int windowDays) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final Map<String, dynamic> timeline = {};
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      timeline[dateStr] = {
        'paise': (15000 + (day.day * 1234) % 30000) * 100.0,
        'lovelace': 0.0,
      };
    }
    return {'timeline': timeline};
  }

  @override
  Future<Map<String, dynamic>> getMerchantInsights(int windowDays) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return {
      'insights': [
        'Weekly gross volume is up 14.2% driven by direct link storefront sales.',
        'Average automated milestone audit settlement time dropped to 1.8 hours.',
        'ZeroPay secure escrows have recorded 0% unresolved disputes.'
      ]
    };
  }

  // Extended Telemetry
  @override
  Future<Map<String, dynamic>> getDiagnosticsQueues() async {
    return {
      'status': 'healthy',
      'activeJobs': 0,
      'completedJobs': 1420,
      'failedJobs': 2,
    };
  }

  @override
  Future<Map<String, dynamic>> getDiagnosticsHealth() async {
    return {
      'status': 'operational',
      'uptime': '99.98%',
      'apiLatencyMs': 45,
    };
  }

  @override
  Future<Map<String, dynamic>> getDiagnosticsRedis() async {
    return {
      'status': 'connected',
      'memoryUsedBytes': 2048576,
      'hitRate': 98.4,
    };
  }

  @override
  Future<Map<String, dynamic>> getDiagnosticsBlockchain() async {
    return {
      'status': 'synchronized',
      'activeNetwork': 'Cardano Mainnet',
      'currentBlock': 9845012,
      'syncPercentage': 100.0,
    };
  }

  // Storefronts & Products
  @override
  Future<Map<String, dynamic>> getMerchantStorefront(String slug) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return {
      'id': 'mer_cryptobrews_789',
      'slug': slug,
      'shopName': 'CryptoBrews Coffee',
      'description': 'Artisanal single-origin coffee roasted fresh and delivered globally.',
      'bannerImageUrl': 'https://images.unsplash.com/photo-1556740749-887f6717d7e4?auto=format&fit=crop&q=80&w=1000',
      'businessHours': '07:00 - 18:00',
      'location': {'city': 'Bengaluru'},
      'walletAddress': 'addr1q8a72b100641de406d824855a782b13fa92c3ff',
      'reputationScore': 98.5,
      'totalOrders': 142,
      'reliabilityTier': 'Gold',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getStorefrontCatalog(String slug) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return [
      {
        'id': 'prod_coffee_1',
        'productId': 'prod_coffee_1',
        'title': 'Artisan Dark Roast Blend',
        'priceLovelace': 15000000,
        'priceINR': 0,
        'price': 15.0,
        'category': 'coffee',
        'isActive': true,
        'images': ['https://images.unsplash.com/photo-1559056199-641a0ac8b55e?auto=format&fit=crop&q=80&w=200'],
      },
      {
        'id': 'prod_coffee_2',
        'productId': 'prod_coffee_2',
        'title': 'Single-Origin Ethiopian Yirgacheffe',
        'priceLovelace': 25000000,
        'priceINR': 0,
        'price': 25.0,
        'category': 'coffee',
        'isActive': true,
        'images': ['https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&q=80&w=200'],
      },
      {
        'id': 'prod_dev_1',
        'productId': 'prod_dev_1',
        'title': 'Fintech Smart Contract Audit',
        'priceLovelace': 250000000,
        'priceINR': 0,
        'price': 250.0,
        'category': 'service',
        'isActive': true,
        'images': ['https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&q=80&w=200'],
      }
    ];
  }

  @override
  Future<Map<String, dynamic>> setupStorefront(Map<String, dynamic> setupData) async {
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> updateStorefront(Map<String, dynamic> updateData) async {
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> createCatalogProduct(Map<String, dynamic> productData) async {
    return {'success': true, 'id': 'prod_new_${DateTime.now().millisecondsSinceEpoch}'};
  }

  @override
  Future<void> deleteCatalogProduct(String id) async {}

  // Marketplace & Feed
  @override
  Future<Map<String, dynamic>> getMarketplaceFeed() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return {
      'merchants': [
        {
          'slug': 'crypto-brews',
          'merchantId': 'mer_cryptobrews_789',
          'shopName': 'CryptoBrews Coffee',
          'description': 'Artisanal single-origin coffee roasted fresh and delivered globally.',
          'category': 'Coffee',
          'reliabilityTier': 'Platinum',
          'reputationScore': 99.8,
          'profileImageUrl': '☕',
          'bannerImageUrl': 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&q=80&w=600',
        },
        {
          'slug': 'devco-solutions',
          'merchantId': 'mer_devco_456',
          'shopName': 'DevCo Solutions',
          'description': 'Premium Flutter and Smart Contract engineering agency.',
          'category': 'Services',
          'reliabilityTier': 'Gold',
          'reputationScore': 96.5,
          'profileImageUrl': '💻',
          'bannerImageUrl': 'https://images.unsplash.com/photo-1486312338219-ce68d2c6f44d?auto=format&fit=crop&q=80&w=600',
        },
        {
          'slug': 'global-logistics',
          'merchantId': 'mer_logistics_101',
          'shopName': 'Global Logistics Corp',
          'description': 'On-chain coordinated freight and customs port handling.',
          'category': 'Logistics',
          'reliabilityTier': 'Silver',
          'reputationScore': 92.0,
          'profileImageUrl': '📦',
          'bannerImageUrl': 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&q=80&w=600',
        }
      ]
    };
  }

  // Dashboard & Invoices
  @override
  Future<Map<String, dynamic>> getMerchantDashboard() async {
    await Future.delayed(const Duration(milliseconds: 50));
    final invoiceItems = _demoData.escrows.map((e) {
      return {
        'invoiceId': e.id,
        'status': e.status == 'Locked' ? 'confirmed' : 'released',
        'amountPaise': e.assetSymbol == 'USDC' ? e.totalValue * 100 : 0.0,
        'amountLovelace': e.assetSymbol == 'ADA' ? e.totalValue * 1000000 : 0.0,
        'isDisputed': e.status == 'Disputed',
        'escrowState': e.status,
      };
    }).toList();

    return {
      'merchant': {
        'id': 'mer_cryptobrews_789',
        'slug': 'crypto-brews',
        'shopName': 'CryptoBrews Coffee',
        'description': 'Artisanal single-origin coffee roasted fresh and delivered globally.',
        'bannerImageUrl': 'https://images.unsplash.com/photo-1556740749-887f6717d7e4?auto=format&fit=crop&q=80&w=1000',
        'businessHours': '07:00 - 18:00',
        'location': {'city': 'Bengaluru'},
        'walletAddress': 'addr1q8a72b100641de406d824855a782b13fa92c3ff',
        'reputationScore': 98.5,
        'totalOrders': 142,
        'reliabilityTier': 'Gold',
      },
      'recentInvoices': invoiceItems,
      'weeklyVolume': 425.0,
      'totalSettled': 12500.0,
    };
  }

  @override
  Future<Map<String, dynamic>> getInvoicesList({int page = 1, int limit = 20, String? status}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final invoiceItems = _demoData.escrows.map((e) {
      return {
        'invoiceId': e.id,
        'status': e.status == 'Locked' ? 'confirmed' : 'released',
        'amountPaise': e.assetSymbol == 'USDC' ? e.totalValue * 100 : 0.0,
        'amountLovelace': e.assetSymbol == 'ADA' ? e.totalValue * 1000000 : 0.0,
        'isDisputed': e.status == 'Disputed',
        'escrowState': e.status,
      };
    }).toList();
    return {'items': invoiceItems};
  }

  // AI Project Planning
  ProjectPlan _createTemplateProjectPlan({
    String? planId,
    int? version,
    required String requirements,
    required int totalAmountPaise,
    String? customerId,
    String? templateName,
  }) {
    final activePlanId = planId ?? 'PLAN-20260606-${(100000 + DateTime.now().millisecondsSinceEpoch % 900000)}';
    final activeVersion = version ?? 1;
    final String key = templateName != null
        ? templateName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')
        : (requirements.toLowerCase().contains('fintech')
            ? 'fintech_app'
            : (requirements.toLowerCase().contains('ai')
                ? 'ai_saas'
                : 'saas_app'));

    String summary = 'Project Plan generated using ZeroPay templates.';
    String scope = 'Implement frontend UI, backend logic, tests, and CI/CD pipelines.';
    List<Map<String, dynamic>> rawMilestones = [];

    if (key.contains('fintech')) {
      summary = 'Compliant Digital Wallet and Ledger system with multi-signature authorization and secure KYC audits.';
      scope = 'Cardano blockchain components, transaction settlement ledger, double-entry DB schema, and local wallet caches.';
      rawMilestones = [
        {'title': 'Ledger Design & DB Schema', 'desc': 'Setup double-entry transactional schemas and account state tables.'},
        {'title': 'User Authentication & JWT', 'desc': 'Create secure JWT token verification routing and user signup validations.'},
        {'title': 'Cardano Node API Sync', 'desc': 'Develop blockchain transaction compilation scripts and address watchers.'},
        {'title': 'Double-Entry Accounting Core', 'desc': 'Code atomic ledger transfers ensuring balance conservation.'},
        {'title': 'Secure HSM Wallet Keys', 'desc': 'Implement encrypted mnemonic seed phrase vaults and API signing routes.'},
        {'title': 'Compliance Reporting Engine', 'desc': 'Generate automated financial reporting, audit logs, and export tools.'},
        {'title': 'Cardano Smart Contracts', 'desc': 'Deploy Plutus validator scripts and compile contract CBOR hashes.'},
        {'title': 'Webhook Events Router', 'desc': 'Build webhook alerts for merchant balance locks and payment releases.'},
        {'title': 'Load Testing & Hot Caches', 'desc': 'Simulate transaction volume stress and optimize Redis cache layers.'},
        {'title': 'Production Security Review', 'desc': 'Run security vulnerability tests, API access check, and final handover.'},
      ];
    } else if (key.contains('ai_saas') || key.contains('ai')) {
      summary = 'Predefined AI agent integration platform featuring NVIDIA Nemotron LLM completions queue and vector search.';
      scope = 'Python FastAPI backend, Next.js client, BullMQ async task processor, Redis cache, and MongoDB.';
      rawMilestones = [
        {'title': 'FastAPI Scaffold & Setup', 'desc': 'Initialize async API endpoints, setup CORS, and configure Pydantic schemas.'},
        {'title': 'Vector Database Indexing', 'desc': 'Deploy Qdrant / Pinecone cluster and code document embedding sync flows.'},
        {'title': 'Prompt Template Engine', 'desc': 'Create parameterized prompt builders with system instructions support.'},
        {'title': 'NVIDIA LLM API Integrator', 'desc': 'Integrate integrate.api.nvidia.com completion endpoints with retries.'},
        {'title': 'BullMQ Task Scheduler', 'desc': 'Build background worker queue logic to handle long LLM prompt tasks.'},
        {'title': 'Multi-Agent Router', 'desc': 'Code orchestrator routing query payloads dynamically between specialized models.'},
        {'title': 'Token Usage Logger', 'desc': 'Develop real-time token tracking middleware writing quota usage to database.'},
        {'title': 'Analytics Dashboard UI', 'desc': 'Implement interactive charts displaying cost trends and agent tokens.'},
        {'title': 'Resilient Failback System', 'desc': 'Configure fallback router transferring failed requests to backup models.'},
        {'title': 'Staging Packaging & Release', 'desc': 'Write production Dockerfiles, compile configs, and execute integration tests.'},
      ];
    } else if (key.contains('marketplace')) {
      summary = 'Multi-vendor marketplace catalog and escrow payout platform for digital services.';
      scope = 'React/Next.js frontend, Node.js gateway API, PostgreSQL, and Sequelize ORM.';
      rawMilestones = [
        {'title': 'Seller Registration Forms', 'desc': 'Create vendor onboarding screens, profiles, and wallet verification.'},
        {'title': 'Catalog Database Model', 'desc': 'Develop relational database tables for categorizing listed products.'},
        {'title': 'Marketplace Discover Feed', 'desc': 'Build storefront home feed with custom query tag filters.'},
        {'title': 'Cart Operations System', 'desc': 'Code local persistent shopping cart items list and tax calculators.'},
        {'title': 'Multi-Party Split Checkout', 'desc': 'Integrate payments router splitting buyer ADA to multiple merchant addresses.'},
        {'title': 'Withdrawal Payout Center', 'desc': 'Develop seller dashboard ledger tracking sales balances and payouts.'},
        {'title': 'Real-time Chat Rooms', 'desc': 'Implement negotiation chat windows connecting buyer and seller accounts.'},
        {'title': 'Refund Dispute Workflow', 'desc': 'Build UI panels to initiate refund requests and submit juror evidence.'},
        {'title': 'CDN Asset Optimization', 'desc': 'Setup Cloudinary / AWS S3 image upload and caching optimizations.'},
        {'title': 'End-to-End Staging Run', 'desc': 'Execute Playwright integration test suites and prepare staging bundle.'},
      ];
    } else if (key.contains('ecommerce')) {
      summary = 'Standard e-commerce platform with catalog listing, shopping cart, Stripe checkout, and emails.';
      scope = 'Astro static storefront, Node.js payment API, Postgres database, and SendGrid mailers.';
      rawMilestones = [
        {'title': 'Product Catalog Schema', 'desc': 'Initialize Postgres database, write product migration scripts, and seed data.'},
        {'title': 'Shop Front Pages', 'desc': 'Build shop list views, category filters, and detailed product cards.'},
        {'title': 'Cart Persistent State', 'desc': 'Configure state management storing selected cart items across page refreshes.'},
        {'title': 'Stripe Checkout API', 'desc': 'Develop server endpoint generating Stripe Checkout sessions dynamically.'},
        {'title': 'Stripe Webhook Listener', 'desc': 'Code listener updating invoice payment state after receiving Stripe webhook.'},
        {'title': 'Order Management Panel', 'desc': 'Build administrator screens displaying chronological orders list and statuses.'},
        {'title': 'Shipping API Integration', 'desc': 'Connect ShipStation / FedEx APIs to compute package delivery rates.'},
        {'title': 'Email Confirmation Engine', 'desc': 'Create SendGrid HTML email template containing order details receipts.'},
        {'title': 'SEO Meta tags & Sitemap', 'desc': 'Optimize metadata tags, configure schema markup, and generate sitemap.xml.'},
        {'title': 'E2E Testing & Staging Deploy', 'desc': 'Write cart checkout integration tests and deploy server container.'},
      ];
    } else if (key.contains('mobile')) {
      summary = 'Cross-platform mobile application utilizing local SQLite cache and secure keychain credentials storage.';
      scope = 'Flutter app client, Riverpod state manager, SQLite database, and REST sync services.';
      rawMilestones = [
        {'title': 'Flutter App Initialization', 'desc': 'Initialize Flutter folder layout, configure colors, and configure routes.'},
        {'title': 'Local SQLite Database', 'desc': 'Develop local database tables caching transaction and profile assets.'},
        {'title': 'Firebase OTP Login UI', 'desc': 'Build phone input form and code code confirmation input screen.'},
        {'title': 'Key Store Storage Hook', 'desc': 'Integrate flutter_secure_storage to persist session jwt tokens.'},
        {'title': 'REST API Network Client', 'desc': 'Develop custom HTTP client with interceptors appending bearer authorization.'},
        {'title': 'Dashboard Bento Grid UI', 'desc': 'Create animated bento card widgets rendering active balance charts.'},
        {'title': 'Push Notifications Handler', 'desc': 'Configure FCM notification listeners updating app badge indicators.'},
        {'title': 'Sync Queue Background worker', 'desc': 'Code background sync scheduler posting offline actions to server.'},
        {'title': 'Widget & Automated Logic Tests', 'desc': 'Write Flutter widget unit tests simulating repository API call outputs.'},
        {'title': 'App Stores Bundling & Build', 'desc': 'Generate signed APK/AAB and package iOS IPA for TestFlight distribution.'},
      ];
    } else if (key.contains('crm')) {
      summary = 'Corporate Relationship Manager system featuring Kanban board pipelines and calendar syncing.';
      scope = 'React web client, Express server APIs, PostgreSQL database, and Cron task handlers.';
      rawMilestones = [
        {'title': 'Lead Management Schema', 'desc': 'Design database schema relating corporate clients to lead actions.'},
        {'title': 'Kanban Stage Pipeline UI', 'desc': 'Implement drag-and-drop board updating lead stages dynamically.'},
        {'title': 'Contact Profile Detail Card', 'desc': 'Build contact files displaying recent communication histories.'},
        {'title': 'Activity History API', 'desc': 'Code endpoint logging meeting notes, calls, and email activities.'},
        {'title': 'Automated Reminders Cron', 'desc': 'Schedule cron task detecting stale deals and emailing assignees.'},
        {'title': 'Revenue Analytics Board', 'desc': 'Develop charts calculating pipeline values and salesperson closes.'},
        {'title': 'Dynamic Field Customizer', 'desc': 'Create settings screen letting admins append custom text attributes.'},
        {'title': 'Email Broadcast Templates', 'desc': 'Integrate Mailgun APIs allowing bulk campaign marketing broadcasts.'},
        {'title': 'Google Calendar OAuth Sync', 'desc': 'Setup OAuth2 flows fetching user events and syncing to pipeline.'},
        {'title': 'Security Authorization Gating', 'desc': 'Enforce role permissions blocking raw lead exports to regular staff.'},
      ];
    } else if (key.contains('developer') || key.contains('tool')) {
      summary = 'Developer CLI application package supporting YAML configurations and background sync utilities.';
      scope = 'Golang/TypeScript command line executable packaging, local folder parsing, and API clients.';
      rawMilestones = [
        {'title': 'CLI Command Scaffolding', 'desc': 'Configure CLI arguments parser supporting custom commands.'},
        {'title': 'YAML Configuration Manager', 'desc': 'Develop configuration reader storing project access tokens locally.'},
        {'title': 'Keychain Credentials Access', 'desc': 'Integrate keytar helper linking CLI to system credentials store.'},
        {'title': 'Local Folder Scanner', 'desc': 'Code recursive directory scanner ignoring dotfiles and lockfiles.'},
        {'title': 'Upload Stream client', 'desc': 'Build network client streaming code snapshots to remote servers.'},
        {'title': 'Asynchronous Sync Handler', 'desc': 'Develop CLI indicator animating synchronization progress.'},
        {'title': 'Markdown Report Printer', 'desc': 'Format analysis outputs into markdown files.'},
        {'title': 'Local Cache SQLite DB', 'desc': 'Setup SQLite database storing sync hash histories to prevent double-upload.'},
        {'title': 'CLI Execution Tests Suite', 'desc': 'Run automated tests verifying CLI parameter parsing and outputs.'},
        {'title': 'Multi-Arch Binary Builder', 'desc': 'Compile binaries for macOS, Linux, and Windows architectures.'},
      ];
    } else if (key.contains('web3')) {
      summary = 'Smart contract coordinate system and web3 dApp browser wallet integration.';
      scope = 'Plutus/Lucid Cardano smart contracts, ethers.js RPC clients, and dispute voting logic.';
      rawMilestones = [
        {'title': 'Plutus Escrow Core Contract', 'desc': 'Write smart contract validator script enforcing milestone payouts.'},
        {'title': 'Lucid Unit Tests Suite', 'desc': 'Develop contract test cases simulating locking and release.'},
        {'title': 'Wallet Context Store', 'desc': 'Build React Context tracking connected browser wallet states.'},
        {'title': 'ADA Transaction Builder', 'desc': 'Code builder compiling contract lock and fund release transactions.'},
        {'title': 'Cardano Blockfrost API Sync', 'desc': 'Connect Cardano RPC endpoint to fetch address utxo states.'},
        {'title': 'Contract Deployer Script', 'desc': 'Write deployment script writing compiled contract hex to mainnet.'},
        {'title': 'On-chain Event Indexer', 'desc': 'Develop indexer indexing contract UTXO status modifications.'},
        {'title': 'Jury Consensus Voting API', 'desc': 'Build endpoint consensus solver routing juror votes to resolution.'},
        {'title': 'Cardano Gas Fee Optimizer', 'desc': 'Refactor Plutus validators to decrease script execution memory.'},
        {'title': 'Mainnet Verification Launch', 'desc': 'Run security penetration tests and launch active mainnet portal.'},
      ];
    } else if (key.contains('startup') || key.contains('mvp')) {
      summary = 'Startup MVP dashboard, landing page waitlist, and analytics feedback captures.';
      scope = 'Tailwind CSS HTML5 interface, serverless Node.js backend handlers, and MongoDB.';
      rawMilestones = [
        {'title': 'Landing Page Layout', 'desc': 'Design responsive landing page featuring value proposition hero.'},
        {'title': 'Waitlist DB Schema', 'desc': 'Setup MongoDB collections storing waitlist email signups.'},
        {'title': 'Serverless Waitlist API', 'desc': 'Develop Node.js serverless functions recording email signups.'},
        {'title': 'Interactive App Runtime UI', 'desc': 'Build basic interactive app features demonstrating platform value.'},
        {'title': 'Onboarding Forms Screen', 'desc': 'Implement onboarding stepper gathering initial user profiles.'},
        {'title': 'Referral Sharing Widget', 'desc': 'Create custom referral buttons sharing invitation links.'},
        {'title': 'Stripe Payment Button', 'desc': 'Integrate single Stripe checkout button securing pre-orders.'},
        {'title': 'Automated Welcome Mailer', 'desc': 'Hook customer signups to trigger Mailchimp welcome campaigns.'},
        {'title': 'SEO Tagging & Site Audits', 'desc': 'Audit landing page speed and optimize metadata tag structures.'},
        {'title': 'One-Click Cloud Launch', 'desc': 'Deploy client code to Vercel and backend APIs to Railway.'},
      ];
    } else {
      // Default to SaaS App template
      summary = 'B2B SaaS dashboard featuring user access controls, Stripe subscription billing, and usage analytics.';
      scope = 'React/Next.js frontend, Express Node.js API, PostgreSQL database, Prisma ORM, and Redis cache.';
      rawMilestones = [
        {'title': 'Product Specifications', 'desc': 'Define user flows, architectural targets, and database design.'},
        {'title': 'Relational DB Schema Init', 'desc': 'Code Prisma migration scripts initializing database schemas.'},
        {'title': 'Auth UI Frontend Layouts', 'desc': 'Build login, registration, and dashboard navigation screens.'},
        {'title': 'Authentication JWT routes', 'desc': 'Code token signature verifications and password hashing rules.'},
        {'title': 'Tenant Management Panels', 'desc': 'Develop admin controls enabling organization settings updates.'},
        {'title': 'Stripe Subscription Core', 'desc': 'Integrate Stripe billing portal creating subscription checkouts.'},
        {'title': 'Stripe Webhooks Receiver', 'desc': 'Write endpoint receiving Stripe event payloads updating user tier.'},
        {'title': 'User Analytics Logging', 'desc': 'Create middleware logging user action histories to database.'},
        {'title': 'System Diagnostics Check', 'desc': 'Optimize SQL queries and setup Redis in-memory caches.'},
        {'title': 'Production Launch Staging', 'desc': 'Containerize applications and deploy onto staging clouds.'},
      ];
    }

    final dbMilestones = <ProjectPlanMilestone>[];
    for (int i = 0; i < 10; i++) {
      final rm = rawMilestones[i];
      final filesList = ['src/components/Milestone_${i+1}.tsx', 'server/src/routes/Milestone_${i+1}.ts'];
      dbMilestones.add(
        ProjectPlanMilestone(
          milestoneId: 'MS-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-00000${i + 1}',
          title: rm['title'] as String,
          description: rm['desc'] as String,
          amountPaise: (totalAmountPaise ~/ 10),
          status: 'pending',
          githubAuditRequirements: GithubAuditReqs(
            requiredFiles: filesList,
            requiredFeatures: <String>[rm['title'] as String],
            requiredTests: <String>[],
            requiredDocumentation: <String>['README.md'],
          ),
        ),
      );
    }

    final dbTasks = <ProjectTask>[
      ProjectTask(
        taskId: 'TSK-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-000001',
        title: 'Project Setup & Repositories Init',
        description: 'Initialize directory structures, lint configurations, and deploy configs.',
        estimatedHours: 8,
        priority: 'high',
        acceptanceCriteria: ['Repository structure setup', 'Base builds succeed'],
        githubAuditRequirements: GithubAuditReqs(
          requiredFiles: ['package.json'],
          requiredFeatures: ['Scaffolding'],
          requiredTests: [],
          requiredDocumentation: ['README.md'],
        ),
      ),
    ];

    final requirementTrace = <RequirementTraceability>[];
    final requirementsBreakdown = <RequirementTrace>[];

    for (int i = 0; i < dbMilestones.length; i++) {
      final ms = dbMilestones[i];
      requirementTrace.add(
        RequirementTraceability(
          requirementId: 'REQ-${(i + 1).toString().padLeft(3, '0')}',
          requirement: ms.title,
          milestoneIds: [ms.milestoneId],
          taskIds: [dbTasks[0].taskId],
          githubAuditRequirements: ms.githubAuditRequirements,
        ),
      );
      requirementsBreakdown.add(
        RequirementTrace(
          requirement: ms.title,
          linkedMilestones: [ms.milestoneId],
          linkedTasks: [dbTasks[0].taskId],
        ),
      );
    }

    final budgetAllocation = <BudgetCategory>[];
    for (final ms in dbMilestones) {
      budgetAllocation.add(
        BudgetCategory(
          category: ms.title,
          percentage: 10,
          amountPaise: ms.amountPaise,
        ),
      );
    }

    return ProjectPlan(
      planId: activePlanId,
      version: activeVersion,
      merchantId: 'mer_cryptobrews_789',
      customerId: customerId ?? 'usr_customer_123',
      requirements: requirements,
      projectSummary: summary,
      scope: scope,
      milestones: dbMilestones,
      tasks: dbTasks,
      requirementsBreakdown: requirementsBreakdown,
      requirementTrace: requirementTrace,
      optimisticDays: 20,
      realisticDays: 30,
      conservativeDays: 45,
      timelineSummary: 'The project requires approximately 30 days of engineering time across 10 milestones.',
      acceptanceCriteria: ['All tests pass on GitHub', 'Milestone deliverables pass audit gates'],
      riskFactors: ['Third-party API rate limits', 'Smart contract deployment gas cost fluctuations'],
      planningConfidence: 95,
      assumptions: ['Developer has active GitHub account', 'Database is configured'],
      unknowns: ['Payment gateway approval turnaround times'],
      budgetAllocation: budgetAllocation,
      escrowStructure: 'Milestone-based progressive release escrow structure.',
      escrowRationale: 'Standard progressive releases balance cashflow and incentivize timely deliveries.',
      status: templateName != null ? 'Template Fallback' : 'AI Generated',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<ProjectPlan> generateProjectPlan({
    required String requirements,
    required int totalAmountPaise,
    String? customerId,
    String? templateName,
    bool? generateAI,
  }) async {
    await Future.delayed(const Duration(milliseconds: 3200));
    final plan = _createTemplateProjectPlan(
      requirements: requirements,
      totalAmountPaise: totalAmountPaise,
      customerId: customerId,
      templateName: templateName,
    );
    _demoData.projectPlans[plan.planId] = [plan];
    return plan;
  }

  @override
  Future<ProjectPlan> getLatestProjectPlan(String planId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final versions = _demoData.projectPlans[planId];
    if (versions == null || versions.isEmpty) {
      throw Exception('Project plan $planId not found');
    }
    return versions.last;
  }

  @override
  Future<List<ProjectPlan>> getProjectPlanVersions(String planId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final versions = _demoData.projectPlans[planId];
    if (versions == null || versions.isEmpty) {
      return [];
    }
    return versions.reversed.toList();
  }

  @override
  Future<ProjectPlan> getProjectPlanVersion(String planId, int version) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final versions = _demoData.projectPlans[planId];
    if (versions == null || versions.isEmpty) {
      throw Exception('Project plan $planId not found');
    }
    final match = versions.where((e) => e.version == version);
    if (match.isEmpty) {
      throw Exception('Version $version not found for plan $planId');
    }
    return match.first;
  }

  @override
  Future<ProjectPlan> updateProjectPlan(String planId, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final versions = _demoData.projectPlans[planId];
    if (versions == null || versions.isEmpty) {
      throw Exception('Project plan $planId not found');
    }
    final latest = versions.last;

    final updatedMilestones = data['milestones'] != null
        ? (data['milestones'] as List)
            .map((e) => ProjectPlanMilestone.fromJson(e as Map<String, dynamic>))
            .toList()
        : latest.milestones;

    final updated = ProjectPlan(
      planId: latest.planId,
      version: latest.version,
      merchantId: latest.merchantId,
      customerId: latest.customerId,
      invoiceId: latest.invoiceId,
      requirements: latest.requirements,
      projectSummary: data['projectSummary'] as String? ?? latest.projectSummary,
      scope: data['scope'] as String? ?? latest.scope,
      milestones: updatedMilestones,
      tasks: latest.tasks,
      requirementsBreakdown: latest.requirementsBreakdown,
      requirementTrace: latest.requirementTrace,
      optimisticDays: latest.optimisticDays,
      realisticDays: latest.realisticDays,
      conservativeDays: latest.conservativeDays,
      timelineSummary: latest.timelineSummary,
      acceptanceCriteria: latest.acceptanceCriteria,
      riskFactors: latest.riskFactors,
      planningConfidence: latest.planningConfidence,
      assumptions: latest.assumptions,
      unknowns: latest.unknowns,
      budgetAllocation: latest.budgetAllocation,
      escrowStructure: latest.escrowStructure,
      escrowRationale: latest.escrowRationale,
      status: 'User Edited',
      createdAt: latest.createdAt,
      updatedAt: DateTime.now(),
    );

    versions.removeLast();
    versions.add(updated);
    _demoData.projectPlans[planId] = versions;
    return updated;
  }

  @override
  Future<ProjectPlan> regenerateProjectPlan(
    String planId, {
    String? requirements,
    int? totalAmountPaise,
    String? customerId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 3200));
    final versions = _demoData.projectPlans[planId];
    if (versions == null || versions.isEmpty) {
      throw Exception('Project plan $planId not found');
    }
    final latest = versions.last;
    final int totalAmount = totalAmountPaise ?? latest.milestones.fold<int>(0, (sum, m) => sum + m.amountPaise);

    final newPlan = _createTemplateProjectPlan(
      planId: planId,
      version: latest.version + 1,
      requirements: requirements ?? latest.requirements,
      totalAmountPaise: totalAmount,
      customerId: customerId ?? latest.customerId,
    );

    versions.add(newPlan);
    _demoData.projectPlans[planId] = versions;
    return newPlan;
  }

  @override
  Future<Map<String, dynamic>> approveProjectPlan(String planId, {String? network}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final versions = _demoData.projectPlans[planId];
    if (versions == null || versions.isEmpty) {
      throw Exception('Project plan $planId not found');
    }
    final latest = versions.last;

    final approved = ProjectPlan(
      planId: latest.planId,
      version: latest.version,
      merchantId: latest.merchantId,
      customerId: latest.customerId,
      invoiceId: 'INV-${(100000 + DateTime.now().millisecondsSinceEpoch % 900000)}',
      requirements: latest.requirements,
      projectSummary: latest.projectSummary,
      scope: latest.scope,
      milestones: latest.milestones,
      tasks: latest.tasks,
      requirementsBreakdown: latest.requirementsBreakdown,
      requirementTrace: latest.requirementTrace,
      optimisticDays: latest.optimisticDays,
      realisticDays: latest.realisticDays,
      conservativeDays: latest.conservativeDays,
      timelineSummary: latest.timelineSummary,
      acceptanceCriteria: latest.acceptanceCriteria,
      riskFactors: latest.riskFactors,
      planningConfidence: latest.planningConfidence,
      assumptions: latest.assumptions,
      unknowns: latest.unknowns,
      budgetAllocation: latest.budgetAllocation,
      escrowStructure: latest.escrowStructure,
      escrowRationale: latest.escrowRationale,
      status: 'Invoice Created',
      createdAt: latest.createdAt,
      updatedAt: DateTime.now(),
    );

    versions.removeLast();
    versions.add(approved);
    _demoData.projectPlans[planId] = versions;

    return {
      'projectPlan': approved,
      'invoice': {
        'invoiceId': approved.invoiceId,
        'amountPaise': approved.milestones.fold<int>(0, (sum, m) => sum + m.amountPaise),
        'amountLovelace': approved.milestones.fold<int>(0, (sum, m) => sum + m.amountPaise) * 25000,
        'status': 'Pending',
        'expiresAt': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        'paymentAddress': 'addr1_active_payment_address_for_invoice_${approved.invoiceId}',
        'network': network ?? 'cardano',
      },
    };
  }

  // GitHub Auditing
  @override
  Future<Map<String, dynamic>> connectGitHubRepository({required String projectPlanId, required String repositoryUrl, String? branch}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final versions = _demoData.projectPlans[projectPlanId];
    if (versions != null && versions.isNotEmpty) {
      final latest = versions.last;
      final sanitizedUrl = repositoryUrl.replaceFirst(RegExp(r'/$'), '');
      final parts = sanitizedUrl.split('/');
      final name = parts.isNotEmpty ? parts.last : 'ZeroPay-app';
      final owner = parts.length >= 2 ? parts[parts.length - 2] : 'madhavansingh';

      final updated = ProjectPlan(
        planId: latest.planId,
        version: latest.version,
        merchantId: latest.merchantId,
        customerId: latest.customerId,
        invoiceId: latest.invoiceId,
        requirements: latest.requirements,
        projectSummary: latest.projectSummary,
        scope: latest.scope,
        milestones: latest.milestones,
        tasks: latest.tasks,
        requirementsBreakdown: latest.requirementsBreakdown,
        requirementTrace: latest.requirementTrace,
        optimisticDays: latest.optimisticDays,
        realisticDays: latest.realisticDays,
        conservativeDays: latest.conservativeDays,
        timelineSummary: latest.timelineSummary,
        acceptanceCriteria: latest.acceptanceCriteria,
        riskFactors: latest.riskFactors,
        planningConfidence: latest.planningConfidence,
        assumptions: latest.assumptions,
        unknowns: latest.unknowns,
        budgetAllocation: latest.budgetAllocation,
        escrowStructure: latest.escrowStructure,
        escrowRationale: latest.escrowRationale,
        status: latest.status,
        createdAt: latest.createdAt,
        updatedAt: DateTime.now(),
        repositoryUrl: repositoryUrl,
        repositoryOwner: owner,
        repositoryName: name,
        branch: branch ?? 'main',
      );
      versions.removeLast();
      versions.add(updated);
      _demoData.projectPlans[projectPlanId] = versions;
    }
    return {'success': true, 'owner': 'madhavansingh', 'name': 'ZeroPay-app'};
  }

  @override
  Future<Map<String, dynamic>> triggerMilestoneAudit({required String projectPlanId, required String milestoneId}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final auditId = 'AUDIT-COMP-${DateTime.now().millisecondsSinceEpoch % 10000}';
    final random = math.Random();
    final score = 75.0 + random.nextDouble() * 20.0;
    final securityScore = 78 + random.nextInt(20);
    final qualityScore = 75 + random.nextInt(22);
    final coverageScore = 70 + random.nextInt(25);
    final documentationScore = 80 + random.nextInt(18);
    final architectureScore = 76 + random.nextInt(20);

    final newAudit = {
      'auditId': auditId,
      'projectPlanId': projectPlanId,
      'milestoneId': milestoneId,
      'auditStatus': 'PASSED',
      'releaseRecommendation': 'RECOMMEND_RELEASE',
      'confidenceScore': score,
      'releaseConfidenceScore': score,
      'auditSummary': 'Dynamic compliance verification completed. All core milestones parsed successfully.',
      'findings': 'Code review confirms complete logic mapping. Security index: $securityScore%. Code quality: $qualityScore%. Coverage: $coverageScore%. Documentation: $documentationScore%. Architecture: $architectureScore%.',
      'implementationCoverage': score,
      'missingRequirements': <String>[],
      'securityIssues': <String>[],
      'requirementTraceMatrix': [
        {
          'requirementId': 'REQ-1',
          'requirement': 'System Core Implementation',
          'status': 'PASSED',
          'completionPercentage': 100,
          'confidenceScore': score.toInt(),
          'evidenceFiles': ['lib/main.dart'],
          'evidenceCommits': ['cfb${random.nextInt(8999) + 1000}'],
          'evidencePRs': ['#${random.nextInt(12) + 1}'],
        }
      ],
      'explainability': {
        'whyVerdictAssigned': 'Verification target matched active codebase signatures.',
        'evidenceUsed': 'Git commits inspection and test logs telemetry.',
        'missingImplementation': 'None',
        'suggestedFixes': 'Minor stylistic warning on trailing commas.',
      },
      'createdAt': DateTime.now().toIso8601String(),
    };

    _demoData.audits.insert(0, newAudit);

    final versions = _demoData.projectPlans[projectPlanId];
    if (versions != null && versions.isNotEmpty) {
      final latest = versions.last;
      final updatedMilestones = latest.milestones.map((m) {
        if (m.milestoneId == milestoneId) {
          return ProjectPlanMilestone(
            milestoneId: m.milestoneId,
            title: m.title,
            description: m.description,
            amountPaise: m.amountPaise,
            status: 'completed',
            githubAuditRequirements: m.githubAuditRequirements,
          );
        }
        return m;
      }).toList();

      final updated = ProjectPlan(
        planId: latest.planId,
        version: latest.version,
        merchantId: latest.merchantId,
        customerId: latest.customerId,
        invoiceId: latest.invoiceId,
        requirements: latest.requirements,
        projectSummary: latest.projectSummary,
        scope: latest.scope,
        milestones: updatedMilestones,
        tasks: latest.tasks,
        requirementsBreakdown: latest.requirementsBreakdown,
        requirementTrace: latest.requirementTrace,
        optimisticDays: latest.optimisticDays,
        realisticDays: latest.realisticDays,
        conservativeDays: latest.conservativeDays,
        timelineSummary: latest.timelineSummary,
        acceptanceCriteria: latest.acceptanceCriteria,
        riskFactors: latest.riskFactors,
        planningConfidence: latest.planningConfidence,
        assumptions: latest.assumptions,
        unknowns: latest.unknowns,
        budgetAllocation: latest.budgetAllocation,
        escrowStructure: latest.escrowStructure,
        escrowRationale: latest.escrowRationale,
        status: latest.status,
        createdAt: latest.createdAt,
        updatedAt: DateTime.now(),
        repositoryUrl: latest.repositoryUrl,
        repositoryOwner: latest.repositoryOwner,
        repositoryName: latest.repositoryName,
        branch: latest.branch,
      );
      versions.removeLast();
      versions.add(updated);
      _demoData.projectPlans[projectPlanId] = versions;
    }

    final eIdx = _demoData.escrows.indexWhere((element) => element.projectPlanId == projectPlanId);
    if (eIdx != -1) {
      final escrow = _demoData.escrows[eIdx];
      final milestones = escrow.milestones.map((m) {
        if (m.id == milestoneId) {
          return Milestone(
            id: m.id,
            title: m.title,
            description: m.description,
            amount: m.amount,
            status: 'Released',
          );
        }
        return m;
      }).toList();

      _demoData.addEscrow(Escrow(
        id: escrow.id,
        title: escrow.title,
        counterpartyAddress: escrow.counterpartyAddress,
        counterpartyName: escrow.counterpartyName,
        totalValue: escrow.totalValue,
        assetSymbol: escrow.assetSymbol,
        status: escrow.status,
        milestones: milestones,
        contractAddress: escrow.contractAddress,
        chainName: escrow.chainName,
        createdAt: escrow.createdAt,
        projectPlanId: escrow.projectPlanId,
      ));
    }

    return {
      'success': true,
      'data': newAudit,
    };
  }

  @override
  Future<Map<String, dynamic>> getGitHubAuditDetails(String auditId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final match = _demoData.audits.where((a) => a['auditId'] == auditId).toList();
    if (match.isNotEmpty) {
      final audit = match.first;
      return {
        'success': true,
        'data': {
          'audit': audit,
          'snapshot': {
            'snapshotId': 'SNAP-COMP-123',
            'repositoryTree': <String>['lib/main.dart', 'pubspec.yaml'],
            'commitHashes': <String>['cfb9824adbe8273645bb9281a8a2723145e6fe7d'],
            'sha256Hash': 'sha256_snapshot_integrity_checksum_enclave_hash',
          },
        },
      };
    }

    return {
      'success': true,
      'data': {
        'audit': {
          'auditId': auditId,
          'auditStatus': 'PASSED',
          'releaseRecommendation': 'RECOMMEND_RELEASE',
          'confidenceScore': 90.0,
          'releaseConfidenceScore': 90.0,
          'auditSummary': 'Milestone audit verified.',
          'findings': 'Code review confirms complete logic mapping.',
          'implementationCoverage': 100.0,
          'missingRequirements': <String>[],
          'securityIssues': <String>[],
          'requirementTraceMatrix': [],
          'explainability': {
            'whyVerdictAssigned': 'AI automated audit evaluation',
            'evidenceUsed': 'Ledger integrity and transaction signature traces',
            'missingImplementation': 'None',
            'suggestedFixes': 'None',
          },
        },
        'snapshot': {
          'snapshotId': 'SNAP-COMP-123',
          'repositoryTree': <String>['src/main.ts'],
          'commitHashes': <String>['c8f391a2bb28384818cc65fa28a8a65bb919a3b2'],
          'sha256Hash': 'activesha256hash',
        },
      },
    };
  }

  @override
  Future<List<dynamic>> getProjectGitHubAudits(String projectPlanId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final list = _demoData.audits.where((a) => a['projectPlanId'] == projectPlanId).toList();
    if (list.isEmpty) {
      return [
        {
          'auditId': 'AUDIT-COMP-123',
          'projectPlanId': projectPlanId,
          'milestoneId': 'MS-1',
          'auditStatus': 'PASSED',
          'releaseRecommendation': 'RECOMMEND_RELEASE',
          'confidenceScore': 95.0,
          'releaseConfidenceScore': 90.0,
          'createdAt': DateTime.now().toIso8601String(),
        }
      ];
    }
    return list;
  }

  @override
  Future<Map<String, dynamic>> reverifyGitHubAudit(String auditId) async {
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> requestGitHubFixes(String auditId, String feedback) async {
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> getGitHubReleaseRecommendation(String auditId) async {
    return {
      'success': true,
      'data': {
        'auditId': auditId,
        'releaseRecommendation': 'RECOMMEND_RELEASE',
        'releaseConfidenceScore': 90,
      },
    };
  }
}

// Riverpod Providers for Cache and Queue
final secureCacheProvider = Provider<SecureCacheManager>((ref) => SecureCacheManager());
final offlineQueueProvider = Provider<OfflineQueueManager>((ref) {
  final client = ref.read(apiClientProvider);
  return OfflineQueueManager(apiClient: client);
});

final zeroPayRepositoryProvider = Provider<ZeroPayRepository>((ref) {
  final dataset = ref.watch(scenarioProfileProvider);
  return RuntimeRepository(dataset);
});
