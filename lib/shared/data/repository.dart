import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models.dart';
import '../providers/global_providers.dart' show DemoDataset;
import 'mock_data.dart';
import 'real_repository.dart';
import '../../core/api/api_services.dart';
import '../../core/security/secure_cache.dart';
import '../../core/security/security_service.dart';
import '../../core/offline/offline_manager.dart';

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
  Future<ProjectPlan> generateProjectPlan({required String requirements, required int totalAmountPaise, String? customerId});
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

// Mock Implementation
class MockZeroPayRepository implements ZeroPayRepository {
  final DemoDataset dataset;
  late User _currentUser;
  late List<Asset> _assets;
  late List<Escrow> _escrows;
  late List<Transaction> _transactions;
  late List<ChatMessage> _chatMessages;
  late List<LedgerEntry> _ledgerHistory;
  late List<WebhookDelivery> _webhookHistory;
  late List<AIRecommendation> _aiRecommendations;
  late DisputeCase _disputeCase;
  final Map<String, List<ProjectPlan>> _mockProjectPlans = {};

  MockZeroPayRepository(this.dataset) {
    _initializeData();
  }

  void _initializeData() {
    switch (dataset) {
      case DemoDataset.newUser:
        _currentUser = User(
          uid: 'usr_new_999',
          email: 'welcome@zeropay.io',
          name: 'New Onboardee',
          currentRole: 'customer',
          biometricsEnabled: false,
          createdAt: DateTime.now(),
        );
        _assets = [];
        _escrows = [];
        _transactions = [];
        _chatMessages = [
          ChatMessage(
            id: 'msg_welcome',
            text: 'Welcome to ZeroPay! Let\'s setup your wallet and link smart contracts to begin trustless commerce.',
            timestamp: DateTime.now(),
            sender: 'ai',
            isAIHelper: true,
          ),
        ];
        _ledgerHistory = [];
        _webhookHistory = [];
        _aiRecommendations = [
          AIRecommendation(
            id: 'rec_new_1',
            category: 'Security',
            title: 'Setup Cardano Wallet',
            description: 'Initialize a secure, trustless wallet to start utilizing blockchain escrows.',
            confidenceScore: 0.99,
          ),
        ];
        _disputeCase = DisputeCase(
          caseId: 'DS-EMPTY',
          title: 'No active disputes',
          disputedAmount: 0.0,
          assetSymbol: 'ADA',
          plaintiffName: '',
          defendantName: '',
          status: 'No Cases',
          filingDate: DateTime.now(),
          consensusLeaningCustomer: 50.0,
          jurors: [],
        );
        break;

      case DemoDataset.activeCustomer:
        _currentUser = MockData.customerUser;
        _assets = List.from(MockData.walletAssets).map((asset) {
          // Adjust balance for customer view
          if (asset.symbol == 'ADA') return Asset(symbol: 'ADA', name: 'Cardano', balance: 5230.50, fiatValue: 2092.20, changePercent24h: 1.2, hexColor: asset.hexColor);
          if (asset.symbol == 'USDC') return Asset(symbol: 'USDC', name: 'USD Coin', balance: 1500.00, fiatValue: 1500.00, changePercent24h: 0.0, hexColor: asset.hexColor);
          return asset;
        }).toList().cast<Asset>();
        _escrows = List.from(MockData.customerEscrows).cast<Escrow>();
        _transactions = List.from(MockData.walletTransactions).where((t) => t.assetSymbol == 'ADA' || t.amount < 1000).toList().cast<Transaction>();
        _chatMessages = List.from(MockData.negotiationMessages).cast<ChatMessage>();
        _ledgerHistory = List.from(MockData.ledgerHistory).where((l) => l.amount < 2000).toList().cast<LedgerEntry>();
        _webhookHistory = List.from(MockData.webhookList).cast<WebhookDelivery>();
        _aiRecommendations = List.from(MockData.aiRecommendationsList).where((r) => r.category != 'Pricing').toList().cast<AIRecommendation>();
        _disputeCase = MockData.activeDisputeCase;
        break;

      case DemoDataset.activeMerchant:
        _currentUser = MockData.merchantUser;
        _assets = List.from(MockData.walletAssets).cast<Asset>();
        _escrows = List.from(MockData.merchantEscrows).cast<Escrow>();
        _transactions = List.from(MockData.walletTransactions).where((t) => t.assetSymbol == 'ETH' || t.amount >= 1000).toList().cast<Transaction>();
        _chatMessages = [];
        _ledgerHistory = List.from(MockData.ledgerHistory).where((l) => l.amount >= 2000).toList().cast<LedgerEntry>();
        _webhookHistory = List.from(MockData.webhookList).cast<WebhookDelivery>();
        _aiRecommendations = List.from(MockData.aiRecommendationsList).where((r) => r.category == 'Pricing').toList().cast<AIRecommendation>();
        _disputeCase = MockData.activeDisputeCase;
        break;

      case DemoDataset.hybridPowerUser:
        _currentUser = User(
          uid: 'usr_hybrid_789',
          email: 'hybrid.pro@lumina.io',
          name: 'Alex Merchant Chen',
          profileImageUrl: MockData.customerUser.profileImageUrl,
          currentRole: 'customer',
          biometricsEnabled: true,
          createdAt: DateTime.now().subtract(const Duration(days: 300)),
        );
        _assets = List.from(MockData.walletAssets);
        _escrows = [...MockData.customerEscrows, ...MockData.merchantEscrows];
        _transactions = List.from(MockData.walletTransactions);
        _chatMessages = List.from(MockData.negotiationMessages);
        _ledgerHistory = List.from(MockData.ledgerHistory);
        _webhookHistory = List.from(MockData.webhookList);
        _aiRecommendations = List.from(MockData.aiRecommendationsList);
        _disputeCase = MockData.activeDisputeCase;
        break;

      case DemoDataset.smallMerchant:
        _currentUser = User(
          uid: 'usr_small_mer',
          email: 'small@merchant.io',
          name: 'Boutique Coffee Roasters',
          currentRole: 'merchant',
          biometricsEnabled: true,
          createdAt: DateTime.now().subtract(const Duration(days: 45)),
        );
        _assets = [
          Asset(symbol: 'ADA', name: 'Cardano', balance: 250.0, fiatValue: 100.0, changePercent24h: 0.5, hexColor: '0xFF0033AD'),
          Asset(symbol: 'USDC', name: 'USD Coin', balance: 120.0, fiatValue: 120.0, changePercent24h: 0.0, hexColor: '0xFF2775CA'),
        ];
        _escrows = [
          Escrow(
            id: 'ZP-1001',
            title: 'Coffee Beans Supply (Batch A)',
            counterpartyAddress: '0x9a8b7c...5544',
            counterpartyName: 'Acme Corp',
            totalValue: 50.0,
            assetSymbol: 'USDC',
            status: 'Locked',
            contractAddress: '0xabcde1001lockedaddress',
            chainName: 'Cardano Mainnet',
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            milestones: [
              Milestone(id: 'ms_sm_1', title: 'Fulfillment', description: 'Ship coffee bags.', amount: 50.0, status: 'In Progress'),
            ],
          ),
        ];
        _transactions = [
          Transaction(
            txHash: '0xabc123...',
            type: 'Escrow Lock',
            assetSymbol: 'USDC',
            amount: 50.0,
            counterpartyAddress: '0x9a8b7c...5544',
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
            status: 'Confirmed',
          ),
        ];
        _chatMessages = [];
        _ledgerHistory = [
          LedgerEntry(
            id: 'led_sm_1',
            assetSymbol: 'USDC',
            amount: 50.0,
            type: 'Debit',
            note: 'Locking fee and escrow creation',
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];
        _webhookHistory = [
          WebhookDelivery(
            id: 'web_sm_1',
            url: 'https://api.smallcoffee.io/events',
            event: 'escrow.created',
            statusCode: 200,
            timestamp: DateTime.now().subtract(const Duration(hours: 12)),
            responseBody: '{"received":true}',
          ),
        ];
        _aiRecommendations = [
          AIRecommendation(
            id: 'rec_sm_1',
            category: 'Pricing',
            title: 'Loyalty Discounts',
            description: 'Offer a 5% discount to Acme Corp to incentivize repeat purchases.',
            confidenceScore: 0.91,
          ),
        ];
        _disputeCase = DisputeCase(
          caseId: 'DS-EMPTY',
          title: 'No active disputes',
          disputedAmount: 0.0,
          assetSymbol: 'ADA',
          plaintiffName: '',
          defendantName: '',
          status: 'No Cases',
          filingDate: DateTime.now(),
          consensusLeaningCustomer: 50.0,
          jurors: [],
        );
        break;

      case DemoDataset.growingMerchant:
        _currentUser = User(
          uid: 'usr_growing_mer',
          email: 'growth@coops.io',
          name: 'Apex Digital Goods',
          currentRole: 'merchant',
          biometricsEnabled: true,
          createdAt: DateTime.now().subtract(const Duration(days: 120)),
        );
        _assets = [
          Asset(symbol: 'ADA', name: 'Cardano', balance: 14500.0, fiatValue: 5800.0, changePercent24h: 1.8, hexColor: '0xFF0033AD'),
          Asset(symbol: 'USDC', name: 'USD Coin', balance: 9200.0, fiatValue: 9200.0, changePercent24h: 0.0, hexColor: '0xFF2775CA'),
        ];
        _escrows = [
          Escrow(
            id: 'ZP-8842',
            title: 'Digital Platform Integration',
            counterpartyAddress: '0x3f5c9e...a912',
            counterpartyName: 'Acme Corp',
            totalValue: 5000.0,
            assetSymbol: 'USDC',
            status: 'Locked',
            contractAddress: '0x8842acme7837e6fe2dba4c6ce',
            chainName: 'Cardano Mainnet',
            createdAt: DateTime.now().subtract(const Duration(days: 10)),
            milestones: [
              Milestone(id: 'ms_gm_1', title: 'API Handshake', description: 'Initial endpoint release.', amount: 2500.0, status: 'Released'),
              Milestone(id: 'ms_gm_2', title: 'Integration Audit', description: 'Verify transaction limits.', amount: 2500.0, status: 'In Progress'),
            ],
          ),
          Escrow(
            id: 'ZP-8843',
            title: 'UI Design Assets',
            counterpartyAddress: '0x3f5c9e...a912',
            counterpartyName: 'Acme Corp',
            totalValue: 1200.0,
            assetSymbol: 'USDC',
            status: 'Disputed',
            contractAddress: '0x8843acme7837e6fe2dba4c6ce',
            chainName: 'Cardano Mainnet',
            createdAt: DateTime.now().subtract(const Duration(days: 15)),
            milestones: [
              Milestone(id: 'ms_gm_3', title: 'Mockup Delivery', description: 'High-fidelity Figma files.', amount: 1200.0, status: 'Disputed'),
            ],
          ),
        ];
        _transactions = [
          Transaction(
            txHash: '0xgtx111...',
            type: 'Escrow Lock',
            assetSymbol: 'USDC',
            amount: 5000.0,
            counterpartyAddress: '0x3f5c9e...a912',
            timestamp: DateTime.now().subtract(const Duration(days: 10)),
            status: 'Confirmed',
          ),
          Transaction(
            txHash: '0xgtx222...',
            type: 'Escrow Release',
            assetSymbol: 'USDC',
            amount: 2500.0,
            counterpartyAddress: '0x3f5c9e...a912',
            timestamp: DateTime.now().subtract(const Duration(days: 4)),
            status: 'Confirmed',
          ),
        ];
        _chatMessages = List.from(MockData.negotiationMessages);
        _ledgerHistory = [
          LedgerEntry(id: 'led_gm_1', assetSymbol: 'USDC', amount: 5000.0, type: 'Credit', note: 'Project Lock', timestamp: DateTime.now().subtract(const Duration(days: 10))),
          LedgerEntry(id: 'led_gm_2', assetSymbol: 'USDC', amount: 2500.0, type: 'Credit', note: 'Milestone Release', timestamp: DateTime.now().subtract(const Duration(days: 4))),
        ];
        _webhookHistory = List.from(MockData.webhookList);
        _aiRecommendations = [
          AIRecommendation(
            id: 'rec_gm_1',
            category: 'Pricing',
            title: 'Dynamic SaaS Tier',
            description: 'Customer integrations are up 40%. Increase corporate rate by 15%.',
            confidenceScore: 0.89,
          ),
          AIRecommendation(
            id: 'rec_gm_2',
            category: 'Negotiation',
            title: 'High Dispute Probability',
            description: 'Figma UI design assets milestone has high risk. Suggest early mediation.',
            confidenceScore: 0.95,
          ),
        ];
        _disputeCase = MockData.activeDisputeCase;
        break;

      case DemoDataset.enterpriseMerchant:
        _currentUser = User(
          uid: 'usr_enterprise_mer',
          email: 'settlement@enterprise.corp',
          name: 'Global Logistics Corp',
          currentRole: 'merchant',
          biometricsEnabled: true,
          createdAt: DateTime.now().subtract(const Duration(days: 450)),
        );
        _assets = [
          Asset(symbol: 'ADA', name: 'Cardano', balance: 540000.0, fiatValue: 216000.0, changePercent24h: 2.5, hexColor: '0xFF0033AD'),
          Asset(symbol: 'USDC', name: 'USD Coin', balance: 1200000.0, fiatValue: 1200000.0, changePercent24h: 0.0, hexColor: '0xFF2775CA'),
        ];
        _escrows = [
          Escrow(
            id: 'ZP-E1',
            title: 'Multi-Modal Logistics Route A',
            counterpartyAddress: '0x992cde...1284',
            counterpartyName: 'TransWorld Supply',
            totalValue: 75000.0,
            assetSymbol: 'USDC',
            status: 'Locked',
            contractAddress: '0xenterpriseescrow_1',
            chainName: 'Cardano Mainnet',
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
            milestones: [
              Milestone(id: 'ms_ent_1', title: 'Port Clearance', description: 'Logistics verification at customs.', amount: 37500.0, status: 'Released'),
              Milestone(id: 'ms_ent_2', title: 'Transit Release', description: 'Train departure confirmation.', amount: 37500.0, status: 'In Progress'),
            ],
          ),
          Escrow(
            id: 'ZP-E2',
            title: 'Raw Material Delivery',
            counterpartyAddress: '0x992cde...1284',
            counterpartyName: 'TransWorld Supply',
            totalValue: 120000.0,
            assetSymbol: 'ADA',
            status: 'Locked',
            contractAddress: '0xenterpriseescrow_2',
            chainName: 'Cardano Mainnet',
            createdAt: DateTime.now().subtract(const Duration(days: 6)),
            milestones: [
              Milestone(id: 'ms_ent_3', title: 'Supply Load', description: 'Silo load operations verified.', amount: 60000.0, status: 'Released'),
              Milestone(id: 'ms_ent_4', title: 'Arrival releasing', description: 'Destination dock release.', amount: 60000.0, status: 'Pending'),
            ],
          ),
        ];
        _transactions = List.generate(15, (index) {
          return Transaction(
            txHash: '0xenthash_$index',
            type: index % 2 == 0 ? 'Escrow Lock' : 'Escrow Release',
            assetSymbol: index % 3 == 0 ? 'ADA' : 'USDC',
            amount: 15000.0 + (index * 2000.0),
            counterpartyAddress: '0x992cde...1284',
            timestamp: DateTime.now().subtract(Duration(days: index)),
            status: 'Confirmed',
          );
        });
        _chatMessages = [];
        _ledgerHistory = List.generate(12, (index) {
          return LedgerEntry(
            id: 'led_ent_$index',
            assetSymbol: index % 2 == 0 ? 'USDC' : 'ADA',
            amount: 25000.0 + (index * 5000.0),
            type: index % 2 == 0 ? 'Credit' : 'Debit',
            note: 'Enterprise cargo settlement block $index',
            timestamp: DateTime.now().subtract(Duration(days: index)),
          );
        });
        _webhookHistory = [
          WebhookDelivery(
            id: 'web_ent_1',
            url: 'https://api.logistics.global/hooks/v1',
            event: 'escrow.released',
            statusCode: 200,
            timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
            responseBody: '{"status":"received"}',
          ),
          WebhookDelivery(
            id: 'web_ent_2',
            url: 'https://api.logistics.global/hooks/v1',
            event: 'escrow.created',
            statusCode: 502,
            timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
            responseBody: 'Bad Gateway - Connection timeout to downstream server.',
          ),
          WebhookDelivery(
            id: 'web_ent_3',
            url: 'https://api.logistics.global/hooks/v1',
            event: 'dispute.filed',
            statusCode: 200,
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
            responseBody: '{"status":"acknowledged"}',
          ),
        ];
        _aiRecommendations = [
          AIRecommendation(
            id: 'rec_ent_1',
            category: 'Security',
            title: 'Multiple Webhook Retries',
            description: 'Downstream webhook endpoint api.logistics.global returned 502 gateway error. System triggered circuit breaker.',
            confidenceScore: 0.98,
          ),
          AIRecommendation(
            id: 'rec_ent_2',
            category: 'Pricing',
            title: 'Hedging ADA volatility',
            description: 'ADA holdings exceed 500k. Suggest converting 30% to USDC settlement buffer.',
            confidenceScore: 0.93,
          ),
        ];
        _disputeCase = DisputeCase(
          caseId: 'DS-EMPTY',
          title: 'No active disputes',
          disputedAmount: 0.0,
          assetSymbol: 'ADA',
          plaintiffName: '',
          defendantName: '',
          status: 'No Cases',
          filingDate: DateTime.now(),
          consensusLeaningCustomer: 50.0,
          jurors: [],
        );
        break;

      case DemoDataset.marketplaceSeller:
        _currentUser = User(
          uid: 'usr_market_mer',
          email: 'seller@zero-marketplace.io',
          name: 'Retro Gaming Source',
          currentRole: 'merchant',
          biometricsEnabled: true,
          createdAt: DateTime.now().subtract(const Duration(days: 80)),
        );
        _assets = [
          Asset(symbol: 'ADA', name: 'Cardano', balance: 3500.0, fiatValue: 1400.0, changePercent24h: -0.2, hexColor: '0xFF0033AD'),
          Asset(symbol: 'USDC', name: 'USD Coin', balance: 4000.0, fiatValue: 4000.0, changePercent24h: 0.0, hexColor: '0xFF2775CA'),
        ];
        _escrows = [
          Escrow(
            id: 'ZP-M1',
            title: 'Vintage Console Lot',
            counterpartyAddress: '0x7c9e12...b998',
            counterpartyName: 'Acme Corp',
            totalValue: 450.0,
            assetSymbol: 'USDC',
            status: 'Locked',
            contractAddress: '0xmarketplace_1',
            chainName: 'Cardano Mainnet',
            createdAt: DateTime.now().subtract(const Duration(hours: 18)),
            milestones: [
              Milestone(id: 'ms_mkt_1', title: 'Shipping Label', description: 'Logistics upload tracking info.', amount: 450.0, status: 'In Progress'),
            ],
          ),
        ];
        _transactions = [
          Transaction(
            txHash: '0xhashmkt1',
            type: 'Escrow Lock',
            assetSymbol: 'USDC',
            amount: 450.0,
            counterpartyAddress: '0x7c9e12...b998',
            timestamp: DateTime.now().subtract(const Duration(hours: 18)),
            status: 'Confirmed',
          ),
        ];
        _chatMessages = [];
        _ledgerHistory = [
          LedgerEntry(id: 'led_mkt_1', assetSymbol: 'USDC', amount: 450.0, type: 'Credit', note: 'Vintage Console Lot Lock', timestamp: DateTime.now().subtract(const Duration(hours: 18))),
        ];
        _webhookHistory = [];
        _aiRecommendations = [
          AIRecommendation(
            id: 'rec_mkt_1',
            category: 'Pricing',
            title: 'Demand Spike: retro consoles',
            description: 'Searches for Vintage NES up 15%. Suggest pricing listings 10% higher.',
            confidenceScore: 0.87,
          ),
        ];
        _disputeCase = DisputeCase(
          caseId: 'DS-EMPTY',
          title: 'No active disputes',
          disputedAmount: 0.0,
          assetSymbol: 'ADA',
          plaintiffName: '',
          defendantName: '',
          status: 'No Cases',
          filingDate: DateTime.now(),
          consensusLeaningCustomer: 50.0,
          jurors: [],
        );
        break;

      case DemoDataset.freelanceProject:
        _currentUser = User(
          uid: 'usr_freelance_cust',
          email: 'client@freelance.io',
          name: 'Sarah Client Jenkins',
          currentRole: 'customer',
          biometricsEnabled: true,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
        );
        _assets = [
          Asset(symbol: 'USDC', name: 'USD Coin', balance: 4500.0, fiatValue: 4500.0, changePercent24h: 0.0, hexColor: '0xFF2775CA'),
        ];
        _escrows = [
          Escrow(
            id: 'ZP-FREL-1',
            title: 'Mobile App Frontend Development',
            counterpartyAddress: '0x9abc...8877',
            counterpartyName: 'DevCo Solutions',
            totalValue: 3000.0,
            assetSymbol: 'USDC',
            status: 'Locked',
            contractAddress: '0xfreelance_escrow_address',
            chainName: 'Cardano Mainnet',
            createdAt: DateTime.now().subtract(const Duration(days: 10)),
            milestones: [
              Milestone(id: 'ms_f_1', title: 'Figma Mockups Verification', description: 'Wireframes signed-off.', amount: 1000.0, status: 'Released'),
              Milestone(id: 'ms_f_2', title: 'Flutter Screens Development', description: 'Phase 2 UI screens build.', amount: 1500.0, status: 'In Progress'),
              Milestone(id: 'ms_f_3', title: 'API Sync Integration', description: 'Final endpoints integrated.', amount: 500.0, status: 'Pending'),
            ],
          ),
        ];
        _transactions = [
          Transaction(txHash: '0xfre001', type: 'Escrow Lock', assetSymbol: 'USDC', amount: 3000.0, counterpartyAddress: 'DevCo Solutions', timestamp: DateTime.now().subtract(const Duration(days: 10)), status: 'Confirmed'),
        ];
        _chatMessages = [
          ChatMessage(id: 'msg_f1', text: 'Hey Sarah! I completed the draft screens for the onboarding flow. Take a look at the repo branch.', timestamp: DateTime.now().subtract(const Duration(hours: 4)), sender: 'counterparty', isAIHelper: false),
          ChatMessage(id: 'msg_f2', text: 'ZeroPay AI analysis: Deliverables detected in github: /features/auth/onboarding. 95% test coverage passed. Safe to trigger milestone release.', timestamp: DateTime.now().subtract(const Duration(hours: 3)), sender: 'ai', isAIHelper: true),
          ChatMessage(id: 'msg_f3', text: 'Thanks! I will review and release the milestone today.', timestamp: DateTime.now().subtract(const Duration(hours: 2)), sender: 'user', isAIHelper: false),
        ];
        _ledgerHistory = [];
        _webhookHistory = [];
        _aiRecommendations = [
          AIRecommendation(id: 'rec_f1', category: 'Security', title: 'Milestone Delivery Verified', description: 'Github repository commit has passed automated automated verification. Recommend milestone release.', confidenceScore: 0.96),
        ];
        _disputeCase = DisputeCase(
          caseId: 'DS-EMPTY',
          title: 'No active disputes',
          disputedAmount: 0.0,
          assetSymbol: 'USDC',
          plaintiffName: '',
          defendantName: '',
          status: 'No Cases',
          filingDate: DateTime.now(),
          consensusLeaningCustomer: 50.0,
          jurors: [],
        );
        break;

      case DemoDataset.agencyContract:
        _currentUser = User(
          uid: 'usr_agency_cust',
          email: 'operations@nexuscorp.io',
          name: 'Nexus Operations Team',
          currentRole: 'customer',
          biometricsEnabled: true,
          createdAt: DateTime.now().subtract(const Duration(days: 90)),
        );
        _assets = [
          Asset(symbol: 'ADA', name: 'Cardano', balance: 85000.0, fiatValue: 34000.0, changePercent24h: 1.5, hexColor: '0xFF0033AD'),
          Asset(symbol: 'USDC', name: 'USD Coin', balance: 50000.0, fiatValue: 50000.0, changePercent24h: 0.0, hexColor: '0xFF2775CA'),
        ];
        _escrows = [
          Escrow(
            id: 'ZP-AGNCY-1',
            title: 'Q3 Brand Assets Package',
            counterpartyAddress: '0xagency...7766',
            counterpartyName: 'Creative Collective LLC',
            totalValue: 15000.0,
            assetSymbol: 'USDC',
            status: 'Locked',
            contractAddress: '0xagency_escrow_address',
            chainName: 'Arbitrum',
            createdAt: DateTime.now().subtract(const Duration(days: 20)),
            milestones: [
              Milestone(id: 'ms_a1', title: 'Brand Deck Delivery', description: 'Logos and branding strategies.', amount: 5000.0, status: 'Released'),
              Milestone(id: 'ms_a2', title: 'Video Commercial Draft', description: '30-second animatic reel.', amount: 10000.0, status: 'In Progress'),
            ],
          ),
        ];
        _transactions = [];
        _chatMessages = [];
        _ledgerHistory = [];
        _webhookHistory = [];
        _aiRecommendations = [];
        _disputeCase = DisputeCase(
          caseId: 'DS-EMPTY',
          title: 'No active disputes',
          disputedAmount: 0.0,
          assetSymbol: 'USDC',
          plaintiffName: '',
          defendantName: '',
          status: 'No Cases',
          filingDate: DateTime.now(),
          consensusLeaningCustomer: 50.0,
          jurors: [],
        );
        break;

      case DemoDataset.marketplacePurchase:
        _currentUser = User(
          uid: 'usr_market_buyer',
          email: 'collector@nesfan.net',
          name: 'Frank Console Collector',
          currentRole: 'customer',
          biometricsEnabled: false,
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
        );
        _assets = [
          Asset(symbol: 'ADA', name: 'Cardano', balance: 800.0, fiatValue: 320.0, changePercent24h: 0.2, hexColor: '0xFF0033AD'),
        ];
        _escrows = [
          Escrow(
            id: 'ZP-MKT-BUY',
            title: 'Vintage NES System & Box',
            counterpartyAddress: '0x99abc...3322',
            counterpartyName: 'Retro Gaming Source',
            totalValue: 200.0,
            assetSymbol: 'ADA',
            status: 'Locked',
            contractAddress: '0xnes_escrow_address',
            chainName: 'Cardano Mainnet',
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
            milestones: [
              Milestone(id: 'ms_m1', title: 'Shipping Label Scanned', description: 'Carrier tracking updated.', amount: 200.0, status: 'In Progress'),
            ],
          ),
        ];
        _transactions = [];
        _chatMessages = [
          ChatMessage(id: 'msg_m1', text: 'Hi, console package has been shipped. Tracking ID is USPS-NES-9801.', timestamp: DateTime.now().subtract(const Duration(days: 1)), sender: 'counterparty', isAIHelper: false),
          ChatMessage(id: 'msg_m2', text: 'ZeroPay AI analysis: USPS status is "Delivered". Safe to confirm milestone release.', timestamp: DateTime.now().subtract(const Duration(hours: 2)), sender: 'ai', isAIHelper: true),
        ];
        _ledgerHistory = [];
        _webhookHistory = [];
        _aiRecommendations = [];
        _disputeCase = DisputeCase(
          caseId: 'DS-EMPTY',
          title: 'No active disputes',
          disputedAmount: 0.0,
          assetSymbol: 'ADA',
          plaintiffName: '',
          defendantName: '',
          status: 'No Cases',
          filingDate: DateTime.now(),
          consensusLeaningCustomer: 50.0,
          jurors: [],
        );
        break;

      case DemoDataset.digitalService:
        _currentUser = User(
          uid: 'usr_digital_cust',
          email: 'domainbuy@venture.co',
          name: 'Venture Capital Acquisitions',
          currentRole: 'customer',
          biometricsEnabled: true,
          createdAt: DateTime.now().subtract(const Duration(days: 50)),
        );
        _assets = [
          Asset(symbol: 'USDC', name: 'USD Coin', balance: 12000.0, fiatValue: 12000.0, changePercent24h: 0.0, hexColor: '0xFF2775CA'),
        ];
        _escrows = [
          Escrow(
            id: 'ZP-DOM-9',
            title: 'Acquisition of lumina.io domain',
            counterpartyAddress: '0x992c...de82',
            counterpartyName: 'Registrar Agents Ltd',
            totalValue: 8500.0,
            assetSymbol: 'USDC',
            status: 'Locked',
            contractAddress: '0xdomain_registrar_address',
            chainName: 'Cardano Mainnet',
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            milestones: [
              Milestone(id: 'ms_d1', title: 'DNS Auth Code Transfer', description: 'Domain authorization codes unlocked.', amount: 8500.0, status: 'In Progress'),
            ],
          ),
        ];
        _transactions = [];
        _chatMessages = [];
        _ledgerHistory = [];
        _webhookHistory = [];
        _aiRecommendations = [
          AIRecommendation(id: 'rec_d1', category: 'Security', title: 'Domain Transfer Inspected', description: 'Registrar codes match authorization formats. Escrow protection verified.', confidenceScore: 0.97),
        ];
        _disputeCase = DisputeCase(
          caseId: 'DS-EMPTY',
          title: 'No active disputes',
          disputedAmount: 0.0,
          assetSymbol: 'USDC',
          plaintiffName: '',
          defendantName: '',
          status: 'No Cases',
          filingDate: DateTime.now(),
          consensusLeaningCustomer: 50.0,
          jurors: [],
        );
        break;

      case DemoDataset.disputedTransaction:
        _currentUser = User(
          uid: 'usr_dispute_cust',
          email: 'plaintiff@lawfirm.com',
          name: 'Alex Chen (Plaintiff)',
          currentRole: 'customer',
          biometricsEnabled: true,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
        );
        _assets = [
          Asset(symbol: 'USDC', name: 'USD Coin', balance: 15000.0, fiatValue: 15000.0, changePercent24h: 0.0, hexColor: '0xFF2775CA'),
        ];
        _escrows = [
          Escrow(
            id: 'ZP-DISP-1',
            title: 'Smart Contract Escrow Transfer',
            counterpartyAddress: '0xdef...8899',
            counterpartyName: 'Nexus Electronics Ltd.',
            totalValue: 12450.0,
            assetSymbol: 'USDC',
            status: 'Disputed',
            contractAddress: '0x8842acme7837e6fe2dba4c6ce',
            chainName: 'Cardano Mainnet',
            createdAt: DateTime.now().subtract(const Duration(days: 15)),
            milestones: [
              Milestone(id: 'ms_ds1', title: 'Hardware Delivery', description: 'Supply components shipment.', amount: 12450.0, status: 'Disputed'),
            ],
          ),
        ];
        _transactions = [];
        _chatMessages = [];
        _ledgerHistory = [];
        _webhookHistory = [];
        _aiRecommendations = [];
        _disputeCase = DisputeCase(
          caseId: 'DS-9281',
          title: 'Smart Contract Escrow Transfer Deliberation',
          disputedAmount: 12450.0,
          assetSymbol: 'USDC',
          plaintiffName: 'Alex Chen',
          defendantName: 'Nexus Electronics Ltd.',
          status: 'Deliberation',
          filingDate: DateTime.now().subtract(const Duration(days: 4)),
          consensusLeaningCustomer: 72.0,
          jurors: [
            Juror(id: 'jr_1', name: 'Juror #302', status: 'Active', hasVoted: true),
            Juror(id: 'jr_2', name: 'Juror #182', status: 'Active', hasVoted: true),
            Juror(id: 'jr_3', name: 'Juror #984', status: 'Active', hasVoted: true),
            Juror(id: 'jr_4', name: 'Juror #102', status: 'Active', hasVoted: true),
            Juror(id: 'jr_5', name: 'Juror #501', status: 'Active', hasVoted: true),
            Juror(id: 'jr_6', name: 'Juror #233', status: 'Pending Vote', hasVoted: false),
            Juror(id: 'jr_7', name: 'Juror #442', status: 'Pending Vote', hasVoted: false),
          ],
        );
        break;

      case DemoDataset.enterpriseEscrow:
        _currentUser = User(
          uid: 'usr_enterprise_cust',
          email: 'logistics@globaltransport.corp',
          name: 'Global Logistics Operations',
          currentRole: 'customer',
          biometricsEnabled: true,
          createdAt: DateTime.now().subtract(const Duration(days: 500)),
        );
        _assets = [
          Asset(symbol: 'ADA', name: 'Cardano', balance: 1200000.0, fiatValue: 480000.0, changePercent24h: 3.2, hexColor: '0xFF0033AD'),
          Asset(symbol: 'USDC', name: 'USD Coin', balance: 5000000.0, fiatValue: 5000000.0, changePercent24h: 0.0, hexColor: '0xFF2775CA'),
        ];
        _escrows = [
          Escrow(
            id: 'ZP-ENT-ROUTE',
            title: 'Cargo Logistics Route Route Europe-A',
            counterpartyAddress: '0x992c...de82',
            counterpartyName: 'Registrar Agents Ltd',
            totalValue: 75000.0,
            assetSymbol: 'USDC',
            status: 'Locked',
            contractAddress: '0xenterprise_route_address',
            chainName: 'Cardano Mainnet',
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
            milestones: [
              Milestone(id: 'ms_ent_a', title: 'Port Clearance Verification', description: 'Logistics cargo cleared at port.', amount: 37500.0, status: 'Released'),
              Milestone(id: 'ms_ent_b', title: 'Departure Gate Release', description: 'Custom cargo gate release verified.', amount: 37500.0, status: 'In Progress'),
            ],
          ),
        ];
        _transactions = [];
        _chatMessages = [];
        _ledgerHistory = [];
        _webhookHistory = [];
        _aiRecommendations = [];
        _disputeCase = DisputeCase(
          caseId: 'DS-EMPTY',
          title: 'No active disputes',
          disputedAmount: 0.0,
          assetSymbol: 'USDC',
          plaintiffName: '',
          defendantName: '',
          status: 'No Cases',
          filingDate: DateTime.now(),
          consensusLeaningCustomer: 50.0,
          jurors: [],
        );
        break;
    }
  }

  @override
  Future<User> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _currentUser;
  }

  @override
  Future<User> switchRole(String role) async {
    _currentUser = _currentUser.copyWith(currentRole: role);
    return _currentUser;
  }

  @override
  Future<User> setBiometricsEnabled(bool enabled) async {
    _currentUser = _currentUser.copyWith(biometricsEnabled: enabled);
    return _currentUser;
  }

  @override
  Future<List<Asset>> getWalletAssets() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _assets;
  }

  @override
  Future<List<Transaction>> getTransactions() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _transactions;
  }

  @override
  Future<void> sendTokens(String address, double amount, String symbol) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    final idx = _assets.indexWhere((element) => element.symbol == symbol);
    if (idx != -1) {
      final currentAsset = _assets[idx];
      if (currentAsset.balance >= amount) {
        _assets[idx] = Asset(
          symbol: symbol,
          name: currentAsset.name,
          balance: currentAsset.balance - amount,
          fiatValue: currentAsset.fiatValue - (amount * (currentAsset.fiatValue / currentAsset.balance)),
          changePercent24h: currentAsset.changePercent24h,
          hexColor: currentAsset.hexColor,
        );
      }
    }

    _transactions.insert(
      0,
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

  @override
  Future<List<Escrow>> getEscrowContracts(String role) async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (role == 'customer') {
      return _escrows.where((element) => element.id != 'ZP-8842').toList();
    } else {
      return _escrows.where((element) => element.id != 'INV-9801').toList();
    }
  }

  @override
  Future<String> createEscrow(Escrow escrow) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _escrows.add(escrow);
    return 'tx_mock_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<Escrow> getEscrowDetails(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _escrows.firstWhere((element) => element.id == id);
  }

  @override
  Future<void> releaseMilestone(String escrowId, String milestoneId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    
    final eIdx = _escrows.indexWhere((element) => element.id == escrowId);
    if (eIdx != -1) {
      final escrow = _escrows[eIdx];
      final mIdx = escrow.milestones.indexWhere((element) => element.id == milestoneId);
      if (mIdx != -1) {
        final milestones = List<Milestone>.from(escrow.milestones);
        final oldM = milestones[mIdx];
        milestones[mIdx] = Milestone(
          id: oldM.id,
          title: oldM.title,
          description: oldM.description,
          amount: oldM.amount,
          status: 'Released',
        );

        final allReleased = milestones.every((element) => element.status == 'Released');
        
        _escrows[eIdx] = Escrow(
          id: escrow.id,
          title: escrow.title,
          counterpartyAddress: escrow.counterpartyAddress,
          counterpartyName: escrow.counterpartyName,
          totalValue: escrow.totalValue,
          assetSymbol: escrow.assetSymbol,
          status: allReleased ? 'Released' : escrow.status,
          milestones: milestones,
          contractAddress: escrow.contractAddress,
          chainName: escrow.chainName,
          createdAt: escrow.createdAt,
        );
      }
    }
  }

  @override
  Future<void> raiseDispute(String escrowId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final eIdx = _escrows.indexWhere((element) => element.id == escrowId);
    if (eIdx != -1) {
      final escrow = _escrows[eIdx];
      _escrows[eIdx] = Escrow(
        id: escrow.id,
        title: escrow.title,
        counterpartyAddress: escrow.counterpartyAddress,
        counterpartyName: escrow.counterpartyName,
        totalValue: escrow.totalValue,
        assetSymbol: escrow.assetSymbol,
        status: 'Disputed',
        milestones: escrow.milestones,
        contractAddress: escrow.contractAddress,
        chainName: escrow.chainName,
        createdAt: escrow.createdAt,
      );
    }
  }

  @override
  Future<DisputeCase> getDisputeCase(String caseId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _disputeCase;
  }

  @override
  Future<void> voteOnDispute(String caseId, String voterId, bool favorPlaintiff) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final updatedJurors = _disputeCase.jurors.map((e) {
      if (e.id == voterId) {
        return Juror(id: e.id, name: e.name, status: 'Voted', hasVoted: true);
      }
      return e;
    }).toList();

    final currentLeaning = _disputeCase.consensusLeaningCustomer;
    final newLeaning = favorPlaintiff ? currentLeaning + 4.0 : currentLeaning - 4.0;

    _disputeCase = DisputeCase(
      caseId: _disputeCase.caseId,
      title: _disputeCase.title,
      disputedAmount: _disputeCase.disputedAmount,
      assetSymbol: _disputeCase.assetSymbol,
      plaintiffName: _disputeCase.plaintiffName,
      defendantName: _disputeCase.defendantName,
      status: _disputeCase.status,
      filingDate: _disputeCase.filingDate,
      consensusLeaningCustomer: newLeaning.clamp(0.0, 100.0),
      jurors: updatedJurors,
    );
  }

  @override
  Future<void> submitEvidence(String caseId, String description) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _disputeCase = DisputeCase(
      caseId: _disputeCase.caseId,
      title: _disputeCase.title,
      disputedAmount: _disputeCase.disputedAmount,
      assetSymbol: _disputeCase.assetSymbol,
      plaintiffName: _disputeCase.plaintiffName,
      defendantName: _disputeCase.defendantName,
      status: 'Deliberation',
      filingDate: _disputeCase.filingDate,
      consensusLeaningCustomer: _disputeCase.consensusLeaningCustomer + 2.0,
      jurors: _disputeCase.jurors,
    );
  }

  @override
  Future<List<AIRecommendation>> getAIRecommendations() async {
    return _aiRecommendations;
  }

  @override
  Future<List<ChatMessage>> getNegotiationChat() async {
    return _chatMessages;
  }

  @override
  Future<List<Milestone>> generateMilestones(String description, double totalAmount, String assetSymbol) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return [
      Milestone(id: 'ms_mock_1', title: 'Milestone 1', description: 'Initial draft and setup', amount: totalAmount * 0.3, status: 'Pending'),
      Milestone(id: 'ms_mock_2', title: 'Milestone 2', description: 'Core functional implementation', amount: totalAmount * 0.5, status: 'Pending'),
      Milestone(id: 'ms_mock_3', title: 'Milestone 3', description: 'Integration and final sign-off', amount: totalAmount * 0.2, status: 'Pending'),
    ];
  }

  @override
  Future<void> sendChatMessage(String roomId, String invoiceId, String message) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _chatMessages.add(
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
    return [];
  }

  @override
  Future<Map<String, dynamic>> getChatRoomDetails(String roomId) async {
    return {};
  }

  @override
  Future<Map<String, dynamic>> createChatRoom(String merchantStringId) async {
    return {};
  }

  @override
  Future<List<LedgerEntry>> getLedgerHistory() async {
    return _ledgerHistory;
  }

  @override
  Future<List<WebhookDelivery>> getWebhookHistory() async {
    return _webhookHistory;
  }

  @override
  Future<Map<String, dynamic>> getMerchantAnalyticsSummary(int windowDays) async => {};

  @override
  Future<Map<String, dynamic>> getMerchantRevenueTimeline(int windowDays) async => {};

  @override
  Future<Map<String, dynamic>> getMerchantInsights(int windowDays) async => {};

  @override
  Future<Map<String, dynamic>> getDiagnosticsQueues() async => {};

  @override
  Future<Map<String, dynamic>> getDiagnosticsHealth() async => {};

  @override
  Future<Map<String, dynamic>> getDiagnosticsRedis() async => {};

  @override
  Future<Map<String, dynamic>> getDiagnosticsBlockchain() async => {};

  @override
  Future<Map<String, dynamic>> getMerchantStorefront(String slug) async => {};

  @override
  Future<List<Map<String, dynamic>>> getStorefrontCatalog(String slug) async => [];

  @override
  Future<Map<String, dynamic>> setupStorefront(Map<String, dynamic> setupData) async => {};

  @override
  Future<Map<String, dynamic>> updateStorefront(Map<String, dynamic> updateData) async => {};

  @override
  Future<Map<String, dynamic>> createCatalogProduct(Map<String, dynamic> productData) async => {};

  @override
  Future<void> deleteCatalogProduct(String id) async {}

  @override
  Future<Map<String, dynamic>> getMarketplaceFeed() async => {};

  @override
  Future<Map<String, dynamic>> getMerchantDashboard() async => {};

  @override
  Future<Map<String, dynamic>> getInvoicesList({int page = 1, int limit = 20, String? status}) async => {};

  ProjectPlan _createMockPlan({
    String? planId,
    int? version,
    required String requirements,
    required int totalAmountPaise,
    String? customerId,
  }) {
    final activePlanId = planId ?? 'PLAN-20260606-${(100000 + DateTime.now().millisecondsSinceEpoch % 900000)}';
    final activeVersion = version ?? 1;
    const m1Id = 'MS-20260606-000001';
    const m2Id = 'MS-20260606-000002';
    const m3Id = 'MS-20260606-000003';
    const t1Id = 'TSK-20260606-000001';
    const t2Id = 'TSK-20260606-000002';
    const t3Id = 'TSK-20260606-000003';

    return ProjectPlan(
      planId: activePlanId,
      version: activeVersion,
      merchantId: 'mer_mock_123',
      customerId: customerId ?? 'usr_active_customer_123',
      requirements: requirements,
      projectSummary: 'Fintech Dashboard Implementation with secure escrows and automated auditing.',
      scope: 'Implement frontend UI, backend services, authentication integration, role-based access controls, push/email notifications, and CI/CD deployment pipelines.',
      milestones: [
        ProjectPlanMilestone(
          milestoneId: m1Id,
          title: 'Database & Auth Setup',
          description: 'Deploy PostgreSQL, set up user schemas, and integrate JWT auth.',
          amountPaise: totalAmountPaise * 30 ~/ 100,
          status: 'pending',
          githubAuditRequirements: GithubAuditReqs(
            requiredFiles: ['server/src/models/User.ts', 'server/src/middleware/auth.ts'],
            requiredFeatures: ['JWT generation', 'Password hashing'],
            requiredTests: ['auth.test.ts'],
            requiredDocumentation: ['API_AUTH.md'],
          ),
        ),
        ProjectPlanMilestone(
          milestoneId: m2Id,
          title: 'Core Dashboard & Analytics',
          description: 'Build analytics engine, transaction tables, and chart widgets.',
          amountPaise: totalAmountPaise * 50 ~/ 100,
          status: 'pending',
          githubAuditRequirements: GithubAuditReqs(
            requiredFiles: ['lib/features/dashboard/presentation/dashboard_screen.dart'],
            requiredFeatures: ['Transaction tables', 'Volume charts'],
            requiredTests: ['dashboard_controller_test.dart'],
            requiredDocumentation: ['ANALYTICS_DOC.md'],
          ),
        ),
        ProjectPlanMilestone(
          milestoneId: m3Id,
          title: 'Role-Based Access & Deploy',
          description: 'Implement permission checking, notification triggers, and deploy to staging.',
          amountPaise: totalAmountPaise * 20 ~/ 100,
          status: 'pending',
          githubAuditRequirements: GithubAuditReqs(
            requiredFiles: ['server/src/middleware/roleCheck.ts', 'Dockerfile'],
            requiredFeatures: ['Staging deployment pipeline'],
            requiredTests: ['permissions.test.ts'],
            requiredDocumentation: ['DEPLOYMENT.md'],
          ),
        ),
      ],
      tasks: [
        ProjectTask(
          taskId: t1Id,
          title: 'Initialize Express Boilerplate',
          description: 'Set up TypeScript, ts-node, ESLint, and basic folder layout.',
          estimatedHours: 8,
          priority: 'high',
          acceptanceCriteria: ['Boilerplate builds', 'Linting passes'],
          githubAuditRequirements: GithubAuditReqs(
            requiredFiles: ['package.json', 'tsconfig.json'],
            requiredFeatures: ['Boilerplate config'],
            requiredTests: [],
            requiredDocumentation: ['README.md'],
          ),
        ),
        ProjectTask(
          taskId: t2Id,
          title: 'Define User Mongoose Models',
          description: 'Create user database tables with secure fields.',
          estimatedHours: 6,
          priority: 'high',
          acceptanceCriteria: ['Models validate correctly', 'Mongoose connects'],
          githubAuditRequirements: GithubAuditReqs(
            requiredFiles: ['server/src/models/User.ts'],
            requiredFeatures: ['User model structure'],
            requiredTests: ['user.test.ts'],
            requiredDocumentation: ['models/README.md'],
          ),
        ),
        ProjectTask(
          taskId: t3Id,
          title: 'Implement Staging pipeline',
          description: 'Write docker file and config files.',
          estimatedHours: 12,
          priority: 'medium',
          acceptanceCriteria: ['Docker builds successfully'],
          githubAuditRequirements: GithubAuditReqs(
            requiredFiles: ['Dockerfile'],
            requiredFeatures: ['Docker deployment support'],
            requiredTests: [],
            requiredDocumentation: ['DEPLOYMENT.md'],
          ),
        ),
      ],
      requirementsBreakdown: [
        RequirementTrace(
          requirement: 'authentication',
          linkedMilestones: [m1Id],
          linkedTasks: [t1Id, t2Id],
        ),
        RequirementTrace(
          requirement: 'analytics dashboard',
          linkedMilestones: [m2Id],
          linkedTasks: [],
        ),
        RequirementTrace(
          requirement: 'role-based access',
          linkedMilestones: [m3Id],
          linkedTasks: [],
        ),
      ],
      requirementTrace: [
        RequirementTraceability(
          requirementId: 'REQ-001',
          requirement: 'authentication',
          milestoneIds: [m1Id],
          taskIds: [t1Id, t2Id],
          githubAuditRequirements: GithubAuditReqs(
            requiredFiles: ['package.json', 'tsconfig.json', 'server/src/models/User.ts'],
            requiredFeatures: ['Boilerplate config', 'User model structure'],
            requiredTests: ['user.test.ts'],
            requiredDocumentation: ['README.md', 'models/README.md'],
          ),
        ),
        RequirementTraceability(
          requirementId: 'REQ-002',
          requirement: 'analytics dashboard',
          milestoneIds: [m2Id],
          taskIds: [],
          githubAuditRequirements: GithubAuditReqs(
            requiredFiles: [],
            requiredFeatures: [],
            requiredTests: [],
            requiredDocumentation: [],
          ),
        ),
        RequirementTraceability(
          requirementId: 'REQ-003',
          requirement: 'role-based access',
          milestoneIds: [m3Id],
          taskIds: [],
          githubAuditRequirements: GithubAuditReqs(
            requiredFiles: [],
            requiredFeatures: [],
            requiredTests: [],
            requiredDocumentation: [],
          ),
        ),
      ],
      optimisticDays: 10,
      realisticDays: 14,
      conservativeDays: 20,
      timelineSummary: 'The project requires 2 weeks of developer resource based on tasks complexity.',
      acceptanceCriteria: ['All tests pass on GitHub', 'All deliverables deployed to staging', 'Final user acceptance signed off'],
      riskFactors: ['Potential rate limit delays', 'Third-party notification API failures'],
      planningConfidence: 92,
      assumptions: ['Developer has access to credentials', 'Server runs 24/7 during test run'],
      unknowns: ['Downstream API status during webhook test'],
      budgetAllocation: [
        BudgetCategory(category: 'Development', percentage: 70, amountPaise: totalAmountPaise * 70 ~/ 100),
        BudgetCategory(category: 'QA & Operations', percentage: 20, amountPaise: totalAmountPaise * 20 ~/ 100),
        BudgetCategory(category: 'Auditing & Gas Fees', percentage: 10, amountPaise: totalAmountPaise * 10 ~/ 100),
      ],
      escrowStructure: 'Linear Milestones',
      escrowRationale: 'Standard linear releases balance cashflow and incentivize timely deliveries.',
      status: 'AI Generated',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<ProjectPlan> generateProjectPlan({
    required String requirements,
    required int totalAmountPaise,
    String? customerId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final plan = _createMockPlan(
      requirements: requirements,
      totalAmountPaise: totalAmountPaise,
      customerId: customerId,
    );
    _mockProjectPlans[plan.planId] = [plan];
    return plan;
  }

  @override
  Future<ProjectPlan> getLatestProjectPlan(String planId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final versions = _mockProjectPlans[planId];
    if (versions == null || versions.isEmpty) {
      throw Exception('Project plan $planId not found');
    }
    return versions.last;
  }

  @override
  Future<List<ProjectPlan>> getProjectPlanVersions(String planId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final versions = _mockProjectPlans[planId];
    if (versions == null || versions.isEmpty) {
      return [];
    }
    return versions.reversed.toList();
  }

  @override
  Future<ProjectPlan> getProjectPlanVersion(String planId, int version) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final versions = _mockProjectPlans[planId];
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
    await Future.delayed(const Duration(milliseconds: 200));
    final versions = _mockProjectPlans[planId];
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
    _mockProjectPlans[planId] = versions;
    return updated;
  }

  @override
  Future<ProjectPlan> regenerateProjectPlan(
    String planId, {
    String? requirements,
    int? totalAmountPaise,
    String? customerId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final versions = _mockProjectPlans[planId];
    if (versions == null || versions.isEmpty) {
      throw Exception('Project plan $planId not found');
    }
    final latest = versions.last;
    final int totalAmount = totalAmountPaise ?? latest.milestones.fold<int>(0, (sum, m) => sum + m.amountPaise);
    
    final newPlan = _createMockPlan(
      planId: planId,
      version: latest.version + 1,
      requirements: requirements ?? latest.requirements,
      totalAmountPaise: totalAmount,
      customerId: customerId ?? latest.customerId,
    );
    
    versions.add(newPlan);
    _mockProjectPlans[planId] = versions;
    return newPlan;
  }

  @override
  Future<Map<String, dynamic>> approveProjectPlan(String planId, {String? network}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final versions = _mockProjectPlans[planId];
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
    _mockProjectPlans[planId] = versions;

    return {
      'projectPlan': approved,
      'invoice': {
        'invoiceId': approved.invoiceId,
        'amountPaise': approved.milestones.fold<int>(0, (sum, m) => sum + m.amountPaise),
        'amountLovelace': approved.milestones.fold<int>(0, (sum, m) => sum + m.amountPaise) * 25000,
        'status': 'Pending',
        'expiresAt': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        'paymentAddress': 'addr1_mock_payment_address_for_invoice_${approved.invoiceId}',
        'network': network ?? 'cardano',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> connectGitHubRepository({required String projectPlanId, required String repositoryUrl, String? branch}) async {
    return {'success': true, 'owner': 'madhavansingh', 'name': 'ZeroPay-app'};
  }

  @override
  Future<Map<String, dynamic>> triggerMilestoneAudit({required String projectPlanId, required String milestoneId}) async {
    return {
      'success': true,
      'data': {
        'auditId': 'AUDIT-MOCK-123',
        'projectPlanId': projectPlanId,
        'milestoneId': milestoneId,
        'auditStatus': 'PASSED',
        'releaseRecommendation': 'RECOMMEND_RELEASE',
        'confidenceScore': 95,
        'releaseConfidenceScore': 90,
        'auditSummary': 'Mock summary',
        'findings': 'Mock findings',
        'implementationCoverage': 100,
        'missingRequirements': <String>[],
        'securityIssues': <String>[],
        'requirementTraceMatrix': [],
        'explainability': {
          'whyVerdictAssigned': 'Mock explain',
          'evidenceUsed': 'Mock evidence',
          'missingImplementation': 'None',
          'suggestedFixes': 'None',
        },
      },
    };
  }

  @override
  Future<Map<String, dynamic>> getGitHubAuditDetails(String auditId) async {
    return {
      'success': true,
      'data': {
        'audit': {
          'auditId': auditId,
          'auditStatus': 'PASSED',
          'releaseRecommendation': 'RECOMMEND_RELEASE',
          'confidenceScore': 95,
          'releaseConfidenceScore': 90,
          'auditSummary': 'Milestone requirements verified.',
          'findings': 'Code tree matches deliverables.',
          'implementationCoverage': 100,
          'missingRequirements': <String>[],
          'securityIssues': <String>[],
          'requirementTraceMatrix': [],
          'explainability': {
            'whyVerdictAssigned': 'Mock explanation',
            'evidenceUsed': 'Mock evidence',
            'missingImplementation': 'None',
            'suggestedFixes': 'None',
          },
        },
        'snapshot': {
          'snapshotId': 'SNAP-MOCK-123',
          'repositoryTree': <String>['src/main.ts'],
          'commitHashes': <String>['c8f391a2bb28384818cc65fa28a8a65bb919a3b2'],
          'sha256Hash': 'mocksha256hash',
        },
      },
    };
  }

  @override
  Future<List<dynamic>> getProjectGitHubAudits(String projectPlanId) async {
    return [
      {
        'auditId': 'AUDIT-MOCK-123',
        'projectPlanId': projectPlanId,
        'milestoneId': 'MS-1',
        'auditStatus': 'PASSED',
        'releaseRecommendation': 'RECOMMEND_RELEASE',
        'confidenceScore': 95,
        'releaseConfidenceScore': 90,
        'createdAt': DateTime.now().toIso8601String(),
      }
    ];
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
  return RealZeroPayRepository(
    authService: ref.read(authApiServiceProvider),
    walletService: ref.read(walletApiServiceProvider),
    escrowService: ref.read(escrowApiServiceProvider),
    aiService: ref.read(aiApiServiceProvider),
    projectService: ref.read(projectApiServiceProvider),
    courtService: ref.read(courtApiServiceProvider),
    telemetryService: ref.read(telemetryApiServiceProvider),
    merchantService: ref.read(merchantApiServiceProvider),
    githubAuditService: ref.read(githubAuditApiServiceProvider),
    securityService: ref.read(securityServiceProvider),
    cache: ref.read(secureCacheProvider),
    queue: ref.read(offlineQueueProvider),
  );
});
