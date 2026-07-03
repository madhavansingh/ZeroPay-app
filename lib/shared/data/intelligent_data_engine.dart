import '../domain/models.dart';
import '../providers/global_providers.dart' show ScenarioProfile;
import 'mock_data.dart';

class IntelligentDataEngine {
  static final IntelligentDataEngine _instance = IntelligentDataEngine._internal();
  factory IntelligentDataEngine() => _instance;
  IntelligentDataEngine._internal() {
    _initializeAllProfiles();
  }

  // Active profile
  ScenarioProfile _currentProfile = ScenarioProfile.hybridPowerUser;
  ScenarioProfile get currentProfile => _currentProfile;

  // In-memory data tables
  final Map<ScenarioProfile, User> _users = {};
  final Map<ScenarioProfile, List<Asset>> _assets = {};
  final Map<ScenarioProfile, List<Escrow>> _escrows = {};
  final Map<ScenarioProfile, List<Transaction>> _transactions = {};
  final Map<ScenarioProfile, List<ChatMessage>> _chatMessages = {};
  final Map<ScenarioProfile, List<LedgerEntry>> _ledgerHistory = {};
  final Map<ScenarioProfile, List<WebhookDelivery>> _webhookHistory = {};
  final Map<ScenarioProfile, List<AIRecommendation>> _aiRecommendations = {};
  final Map<ScenarioProfile, DisputeCase> _disputeCases = {};

  // Global collections (shared across profiles)
  final Map<String, List<ProjectPlan>> projectPlans = {};
  final List<Map<String, dynamic>> audits = [];

  // Active profile accessors
  User get currentUser => _users[_currentProfile]!;
  List<Asset> get assets => _assets[_currentProfile] ?? [];
  List<Escrow> get escrows => _escrows[_currentProfile] ?? [];
  List<Transaction> get transactions => _transactions[_currentProfile] ?? [];
  List<ChatMessage> get chatMessages => _chatMessages[_currentProfile] ?? [];
  List<LedgerEntry> get ledgerHistory => _ledgerHistory[_currentProfile] ?? [];
  List<WebhookDelivery> get webhookHistory => _webhookHistory[_currentProfile] ?? [];
  List<AIRecommendation> get aiRecommendations => _aiRecommendations[_currentProfile] ?? [];
  DisputeCase get disputeCase => _disputeCases[_currentProfile]!;

  void setProfile(ScenarioProfile profile) {
    _currentProfile = profile;
  }

  void _initializeAllProfiles() {
    for (final profile in ScenarioProfile.values) {
      _initializeProfile(profile);
    }
  }

  void _initializeProfile(ScenarioProfile profile) {
    switch (profile) {
      case ScenarioProfile.newUser:
        _users[profile] = User(
          uid: 'usr_new_999',
          email: 'welcome@zeropay.io',
          name: 'New Onboardee',
          currentRole: 'customer',
          biometricsEnabled: false,
          createdAt: DateTime.now(),
        );
        _assets[profile] = [];
        _escrows[profile] = [];
        _transactions[profile] = [];
        _chatMessages[profile] = [
          ChatMessage(
            id: 'msg_welcome',
            text: 'Welcome to ZeroPay! Let\'s setup your wallet and link smart contracts to begin trustless commerce.',
            timestamp: DateTime.now(),
            sender: 'ai',
            isAIHelper: true,
          ),
        ];
        _ledgerHistory[profile] = [];
        _webhookHistory[profile] = [];
        _aiRecommendations[profile] = [
          AIRecommendation(
            id: 'rec_new_1',
            category: 'Security',
            title: 'Setup Cardano Wallet',
            description: 'Initialize a secure, trustless wallet to start utilizing blockchain escrows.',
            confidenceScore: 0.99,
          ),
        ];
        _disputeCases[profile] = DisputeCase(
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

      case ScenarioProfile.activeCustomer:
        _users[profile] = MockData.customerUser;
        _assets[profile] = List.from(MockData.walletAssets).map((asset) {
          if (asset.symbol == 'ADA') return Asset(symbol: 'ADA', name: 'Cardano', balance: 5230.50, fiatValue: 2092.20, changePercent24h: 1.2, hexColor: asset.hexColor);
          if (asset.symbol == 'USDC') return Asset(symbol: 'USDC', name: 'USD Coin', balance: 1500.00, fiatValue: 1500.00, changePercent24h: 0.0, hexColor: asset.hexColor);
          return asset;
        }).toList().cast<Asset>();
        _escrows[profile] = List.from(MockData.customerEscrows).cast<Escrow>();
        _transactions[profile] = List.from(MockData.walletTransactions).where((t) => t.assetSymbol == 'ADA' || t.amount < 1000).toList().cast<Transaction>();
        _chatMessages[profile] = List.from(MockData.negotiationMessages).cast<ChatMessage>();
        _ledgerHistory[profile] = List.from(MockData.ledgerHistory).where((l) => l.amount < 2000).toList().cast<LedgerEntry>();
        _webhookHistory[profile] = List.from(MockData.webhookList).cast<WebhookDelivery>();
        _aiRecommendations[profile] = List.from(MockData.aiRecommendationsList).where((r) => r.category != 'Pricing').toList().cast<AIRecommendation>();
        _disputeCases[profile] = MockData.activeDisputeCase;
        break;

      case ScenarioProfile.activeMerchant:
        _users[profile] = MockData.merchantUser;
        _assets[profile] = List.from(MockData.walletAssets).cast<Asset>();
        _escrows[profile] = List.from(MockData.merchantEscrows).cast<Escrow>();
        _transactions[profile] = List.from(MockData.walletTransactions).where((t) => t.assetSymbol == 'ETH' || t.amount >= 1000).toList().cast<Transaction>();
        _chatMessages[profile] = [];
        _ledgerHistory[profile] = List.from(MockData.ledgerHistory).where((l) => l.amount >= 2000).toList().cast<LedgerEntry>();
        _webhookHistory[profile] = List.from(MockData.webhookList).cast<WebhookDelivery>();
        _aiRecommendations[profile] = List.from(MockData.aiRecommendationsList).where((r) => r.category == 'Pricing').toList().cast<AIRecommendation>();
        _disputeCases[profile] = MockData.activeDisputeCase;
        break;

      case ScenarioProfile.hybridPowerUser:
        _users[profile] = User(
          uid: 'usr_hybrid_789',
          email: 'hybrid.pro@lumina.io',
          name: 'Alex Merchant Chen',
          profileImageUrl: MockData.customerUser.profileImageUrl,
          currentRole: 'customer',
          biometricsEnabled: true,
          createdAt: DateTime.now().subtract(const Duration(days: 300)),
        );
        _assets[profile] = List.from(MockData.walletAssets);
        _escrows[profile] = [...MockData.customerEscrows, ...MockData.merchantEscrows];
        _transactions[profile] = List.from(MockData.walletTransactions);
        _chatMessages[profile] = List.from(MockData.negotiationMessages);
        _ledgerHistory[profile] = List.from(MockData.ledgerHistory);
        _webhookHistory[profile] = List.from(MockData.webhookList);
        _aiRecommendations[profile] = List.from(MockData.aiRecommendationsList);
        _disputeCases[profile] = MockData.activeDisputeCase;
        break;

      case ScenarioProfile.smallMerchant:
        _users[profile] = User(
          uid: 'usr_small_mer',
          email: 'small@merchant.io',
          name: 'Boutique Coffee Roasters',
          currentRole: 'merchant',
          biometricsEnabled: true,
          createdAt: DateTime.now().subtract(const Duration(days: 45)),
        );
        _assets[profile] = [
          Asset(symbol: 'ADA', name: 'Cardano', balance: 250.0, fiatValue: 100.0, changePercent24h: 0.5, hexColor: '0xFF0033AD'),
          Asset(symbol: 'USDC', name: 'USD Coin', balance: 120.0, fiatValue: 120.0, changePercent24h: 0.0, hexColor: '0xFF2775CA'),
        ];
        _escrows[profile] = [
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
        _transactions[profile] = [
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
        _chatMessages[profile] = [];
        _ledgerHistory[profile] = [
          LedgerEntry(
            id: 'led_sm_1',
            assetSymbol: 'USDC',
            amount: 50.0,
            type: 'Debit',
            note: 'Locking fee and escrow creation',
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];
        _webhookHistory[profile] = [
          WebhookDelivery(
            id: 'web_sm_1',
            url: 'https://api.smallcoffee.io/events',
            event: 'escrow.created',
            statusCode: 200,
            timestamp: DateTime.now().subtract(const Duration(hours: 12)),
            responseBody: '{"received":true}',
          ),
        ];
        _aiRecommendations[profile] = [
          AIRecommendation(
            id: 'rec_sm_1',
            category: 'Pricing',
            title: 'Loyalty Discounts',
            description: 'Offer a 5% discount to Acme Corp to incentivize repeat purchases.',
            confidenceScore: 0.91,
          ),
        ];
        _disputeCases[profile] = DisputeCase(
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

      case ScenarioProfile.growingMerchant:
        _users[profile] = User(
          uid: 'usr_growing_mer',
          email: 'growth@coops.io',
          name: 'Apex Digital Goods',
          currentRole: 'merchant',
          biometricsEnabled: true,
          createdAt: DateTime.now().subtract(const Duration(days: 120)),
        );
        _assets[profile] = [
          Asset(symbol: 'ADA', name: 'Cardano', balance: 14500.0, fiatValue: 5800.0, changePercent24h: 1.8, hexColor: '0xFF0033AD'),
          Asset(symbol: 'USDC', name: 'USD Coin', balance: 9200.0, fiatValue: 9200.0, changePercent24h: 0.0, hexColor: '0xFF2775CA'),
        ];
        _escrows[profile] = [
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
        _transactions[profile] = [
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
        _chatMessages[profile] = List.from(MockData.negotiationMessages);
        _ledgerHistory[profile] = [
          LedgerEntry(id: 'led_gm_1', assetSymbol: 'USDC', amount: 5000.0, type: 'Credit', note: 'Project Lock', timestamp: DateTime.now().subtract(const Duration(days: 10))),
          LedgerEntry(id: 'led_gm_2', assetSymbol: 'USDC', amount: 2500.0, type: 'Credit', note: 'Milestone Release', timestamp: DateTime.now().subtract(const Duration(days: 4))),
        ];
        _webhookHistory[profile] = List.from(MockData.webhookList);
        _aiRecommendations[profile] = [
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
        _disputeCases[profile] = MockData.activeDisputeCase;
        break;

      case ScenarioProfile.enterpriseMerchant:
        _users[profile] = User(
          uid: 'usr_enterprise_mer',
          email: 'settlement@enterprise.corp',
          name: 'Global Logistics Corp',
          currentRole: 'merchant',
          biometricsEnabled: true,
          createdAt: DateTime.now().subtract(const Duration(days: 450)),
        );
        _assets[profile] = [
          Asset(symbol: 'ADA', name: 'Cardano', balance: 540000.0, fiatValue: 216000.0, changePercent24h: 2.5, hexColor: '0xFF0033AD'),
          Asset(symbol: 'USDC', name: 'USD Coin', balance: 1200000.0, fiatValue: 1200000.0, changePercent24h: 0.0, hexColor: '0xFF2775CA'),
        ];
        _escrows[profile] = [
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
        _transactions[profile] = List.generate(15, (index) {
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
        _chatMessages[profile] = [];
        _ledgerHistory[profile] = List.generate(12, (index) {
          return LedgerEntry(
            id: 'led_ent_$index',
            assetSymbol: index % 2 == 0 ? 'USDC' : 'ADA',
            amount: 25000.0 + (index * 5000.0),
            type: index % 2 == 0 ? 'Credit' : 'Debit',
            note: 'Enterprise cargo settlement block $index',
            timestamp: DateTime.now().subtract(Duration(days: index)),
          );
        });
        _webhookHistory[profile] = [
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
        _aiRecommendations[profile] = [
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
        _disputeCases[profile] = DisputeCase(
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

      default:
        // Setup same defaults for other items to prevent null refs
        _users[profile] = MockData.customerUser;
        _assets[profile] = List.from(MockData.walletAssets).cast<Asset>();
        _escrows[profile] = List.from(MockData.customerEscrows).cast<Escrow>();
        _transactions[profile] = List.from(MockData.walletTransactions).cast<Transaction>();
        _chatMessages[profile] = [];
        _ledgerHistory[profile] = List.from(MockData.ledgerHistory).cast<LedgerEntry>();
        _webhookHistory[profile] = [];
        _aiRecommendations[profile] = [];
        _disputeCases[profile] = MockData.activeDisputeCase;
    }
  }

  // Mutator operations for Escrow Lifecycles
  void addEscrow(Escrow escrow) {
    final list = _escrows[_currentProfile] ?? [];
    list.removeWhere((e) => e.id == escrow.id);
    list.add(escrow);
    _escrows[_currentProfile] = list;
  }

  void updateEscrowStatus(String escrowId, String status) {
    final list = _escrows[_currentProfile] ?? [];
    final idx = list.indexWhere((e) => e.id == escrowId);
    if (idx != -1) {
      final old = list[idx];
      list[idx] = Escrow(
        id: old.id,
        title: old.title,
        counterpartyAddress: old.counterpartyAddress,
        counterpartyName: old.counterpartyName,
        totalValue: old.totalValue,
        assetSymbol: old.assetSymbol,
        status: status,
        milestones: old.milestones,
        contractAddress: old.contractAddress,
        chainName: old.chainName,
        createdAt: old.createdAt,
        chatRoomId: old.chatRoomId,
        merchantStringId: old.merchantStringId,
        projectPlanId: old.projectPlanId,
      );
    }
  }

  void releaseMilestone(String escrowId, String milestoneId) {
    final list = _escrows[_currentProfile] ?? [];
    final idx = list.indexWhere((e) => e.id == escrowId);
    if (idx != -1) {
      final escrow = list[idx];
      final updatedM = escrow.milestones.map((m) {
        if (m.id == milestoneId) {
          return Milestone(id: m.id, title: m.title, description: m.description, amount: m.amount, status: 'Released');
        }
        return m;
      }).toList();

      final allReleased = updatedM.every((m) => m.status == 'Released');

      list[idx] = Escrow(
        id: escrow.id,
        title: escrow.title,
        counterpartyAddress: escrow.counterpartyAddress,
        counterpartyName: escrow.counterpartyName,
        totalValue: escrow.totalValue,
        assetSymbol: escrow.assetSymbol,
        status: allReleased ? 'Released' : escrow.status,
        milestones: updatedM,
        contractAddress: escrow.contractAddress,
        chainName: escrow.chainName,
        createdAt: escrow.createdAt,
        chatRoomId: escrow.chatRoomId,
        merchantStringId: escrow.merchantStringId,
        projectPlanId: escrow.projectPlanId,
      );
    }
  }

  void deductWalletBalance(double amount, String symbol) {
    final list = _assets[_currentProfile] ?? [];
    final idx = list.indexWhere((e) => e.symbol == symbol);
    if (idx != -1) {
      final asset = list[idx];
      list[idx] = Asset(
        symbol: asset.symbol,
        name: asset.name,
        balance: (asset.balance - amount).clamp(0.0, double.infinity),
        fiatValue: (asset.balance - amount).clamp(0.0, double.infinity) * (asset.fiatValue / (asset.balance == 0 ? 1 : asset.balance)),
        changePercent24h: asset.changePercent24h,
        hexColor: asset.hexColor,
      );
    }
  }

  void addWalletBalance(double amount, String symbol) {
    final list = _assets[_currentProfile] ?? [];
    final idx = list.indexWhere((e) => e.symbol == symbol);
    if (idx != -1) {
      final asset = list[idx];
      list[idx] = Asset(
        symbol: asset.symbol,
        name: asset.name,
        balance: asset.balance + amount,
        fiatValue: (asset.balance + amount) * (asset.fiatValue / (asset.balance == 0 ? 1 : asset.balance)),
        changePercent24h: asset.changePercent24h,
        hexColor: asset.hexColor,
      );
    }
  }

  void addTransaction(Transaction tx) {
    final list = _transactions[_currentProfile] ?? [];
    list.insert(0, tx);
    _transactions[_currentProfile] = list;
  }

  void updateUser(User user) {
    _users[_currentProfile] = user;
  }

  void updateDisputeCase(DisputeCase dc) {
    _disputeCases[_currentProfile] = dc;
  }

  void addChatMessage(ChatMessage msg) {
    final list = _chatMessages[_currentProfile] ?? [];
    list.add(msg);
    _chatMessages[_currentProfile] = list;
  }
}
