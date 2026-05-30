import '../domain/models.dart';

class MockData {
  MockData._();

  // Mock User
  static final User customerUser = User(
    uid: 'usr_customer_123',
    email: 'alex.chen@lumina.io',
    name: 'Alex Chen',
    profileImageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCS4SuleMBSuahovxp2CD_tX-Ez_k7WRJ43_FGqUQqaFSrEJOpBbIij1ctKcBCCeU9gGMHYl8QJeR9RCi4O5fMMsFrB-Llv7vRmHmvDeQwyJ6qwTQ4sRacN5ciOc5xXhghUcdrDXSrM1s-SufdCzjIE0YxRW2RVqbooD0ceqQFDiSOUqqSm1LgVFFO7ESHk4JudGD7WEWXomM-jmwe-jsy8Aomt36I34xOGpoP26elm_rvOKlnOeYaybk5MFeFiqp1xKDSSw5MGGTKp',
    currentRole: 'customer',
    biometricsEnabled: true,
    createdAt: DateTime.now().subtract(const Duration(days: 300)),
  );

  static final User merchantUser = User(
    uid: 'usr_merchant_456',
    email: 'merchant@cryptobrews.eth',
    name: 'Verified Merchant',
    profileImageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCdfAeOMz-hFgPjpiSRxpTx0AAlPyn8qa-XK6UpF-3R3lWc2cTNz15gXwvfYDGcLnRJ0aSQxr9fQuTxZUMEUge2NAeynKx2UZ_pSvK8m8mbdydskZuUmqCAWgD53bCs0cxzYSlzrKHjgJBNMN-muTLZGUwCRojxEU-hL11_FqT-oqAxscm6P6nTZKsEIV8CZvw54mcerz09JqJ1iZb4rURhHwTr6oMA1f0oUdsq1XD2oKu-VXBXR_XwFZMlXIDQ8w6vdyYRzrXbxoxt',
    currentRole: 'merchant',
    biometricsEnabled: true,
    createdAt: DateTime.now().subtract(const Duration(days: 200)),
  );

  // Mock Merchant Profile
  static final Merchant cryptoBrewsMerchant = Merchant(
    id: 'mer_cryptobrews_789',
    name: 'CryptoBrews Coffee',
    tier: 'Platinum',
    trustScore: 99.8,
    description: 'Premium artisanal coffee accepting web3 payments.',
    email: 'hello@cryptobrews.eth',
    address: '124 Satoshi St, Block 4',
    businessHours: {
      'Mon - Fri': '07:00 - 18:00',
      'Saturday': '08:00 - 16:00',
      'Sunday': 'Closed',
    },
    logoUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCdfAeOMz-hFgPjpiSRxpTx0AAlPyn8qa-XK6UpF-3R3lWc2cTNz15gXwvfYDGcLnRJ0aSQxr9fQuTxZUMEUge2NAeynKx2UZ_pSvK8m8mbdydskZuUmqCAWgD53bCs0cxzYSlzrKHjgJBNMN-muTLZGUwCRojxEU-hL11_FqT-oqAxscm6P6nTZKsEIV8CZvw54mcerz09JqJ1iZb4rURhHwTr6oMA1f0oUdsq1XD2oKu-VXBXR_XwFZMlXIDQ8w6vdyYRzrXbxoxt',
    bannerUrl: 'https://images.unsplash.com/photo-1556740749-887f6717d7e4?auto=format&fit=crop&q=80&w=1000',
  );

  // Mock Assets
  static final List<Asset> walletAssets = [
    Asset(
      symbol: 'ADA',
      name: 'Cardano',
      balance: 45230.50,
      fiatValue: 18092.20,
      changePercent24h: 1.2,
      hexColor: '0xFF0033AD',
    ),
    Asset(
      symbol: 'USDC',
      name: 'USD Coin',
      balance: 85000.00,
      fiatValue: 85000.00,
      changePercent24h: 0.0,
      hexColor: '0xFF2775CA',
    ),
    Asset(
      symbol: 'ETH',
      name: 'Ethereum',
      balance: 6.45,
      fiatValue: 21500.60,
      changePercent24h: -0.8,
      hexColor: '0xFF627EEA',
    ),
  ];

  static final List<Asset> updatedAssets = [
    Asset(
      symbol: 'ADA',
      name: 'Cardano',
      balance: 45230.50,
      fiatValue: 18210.30,
      changePercent24h: 2.1,
      hexColor: '0xFF0033AD',
    ),
    Asset(
      symbol: 'USDC',
      name: 'USD Coin',
      balance: 85000.00,
      fiatValue: 85000.00,
      changePercent24h: 0.0,
      hexColor: '0xFF2775CA',
    ),
    Asset(
      symbol: 'ETH',
      name: 'Ethereum',
      balance: 6.45,
      fiatValue: 21620.10,
      changePercent24h: -0.2,
      hexColor: '0xFF627EEA',
    ),
  ];

  // Mock Escrows
  static final List<Escrow> customerEscrows = [
    Escrow(
      id: 'INV-9801',
      title: 'Freelance Design & Development',
      counterpartyAddress: '0x8a72b1...4f21',
      counterpartyName: 'BlockMasons Inc.',
      totalValue: 450.0,
      assetSymbol: 'ADA',
      status: 'Locked',
      contractAddress: '0x8f7c9e4a13a7dcb2a1e74e5d1e',
      chainName: 'Cardano Mainnet',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      milestones: [
        Milestone(
          id: 'ms_1',
          title: 'Design Phase',
          description: 'Wireframes and UI mockups approved.',
          amount: 150.0,
          status: 'Released',
        ),
        Milestone(
          id: 'ms_2',
          title: 'Development',
          description: 'Smart contract integration and frontend build.',
          amount: 200.0,
          status: 'In Progress',
        ),
        Milestone(
          id: 'ms_3',
          title: 'Testing & Handover',
          description: 'Final audit and source code delivery.',
          amount: 100.0,
          status: 'Pending',
        ),
      ],
    ),
  ];

  static final List<Escrow> merchantEscrows = [
    Escrow(
      id: 'ZP-8842',
      title: 'Acme Corp Asset Transfer',
      counterpartyAddress: '0x3f5c9e...a912',
      counterpartyName: 'Acme Corp',
      totalValue: 12.5,
      assetSymbol: 'ETH',
      status: 'Locked',
      contractAddress: '0x8842acme7837e6fe2dba4c6ce',
      chainName: 'Ethereum Mainnet',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      milestones: [
        Milestone(
          id: 'ms_10',
          title: 'Asset Acquisition',
          description: 'Transfer intellectual property files.',
          amount: 6.25,
          status: 'Released',
        ),
        Milestone(
          id: 'ms_20',
          title: 'Auditing',
          description: 'AI auditing of transferred assets.',
          amount: 6.25,
          status: 'In Progress',
        ),
      ],
    ),
  ];

  // Mock Dispute Case
  static final DisputeCase activeDisputeCase = DisputeCase(
    caseId: 'DS-9281',
    title: 'Smart Contract Escrow Transfer Deliberation',
    disputedAmount: 12450.00,
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

  // Mock Notifications
  static final List<Notification> notificationsList = [
    Notification(
      id: 'not_1',
      title: 'Dispute Opened',
      description: 'A dispute has been raised for Order #8889 regarding shipping delays.',
      category: 'Dispute',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
    ),
    Notification(
      id: 'not_2',
      title: 'Mnemonic Backed Up',
      description: 'Your wallet recovery phrase has been successfully verified.',
      category: 'Security',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
  ];

  // Mock Transactions
  static final List<Transaction> walletTransactions = [
    Transaction(
      txHash: '0x9d4a8e2bc17a4c38a703a1f406d7d6f6a73c1553',
      type: 'Escrow Lock',
      assetSymbol: 'ADA',
      amount: 450.0,
      counterpartyAddress: '0x8a72b1...4f21',
      timestamp: DateTime.now().subtract(const Duration(days: 5)),
      status: 'Confirmed',
    ),
    Transaction(
      txHash: '0xf3d8b796ed6748038ad7dd7d53100641de406d82',
      type: 'Receive',
      assetSymbol: 'USDC',
      amount: 1500.0,
      counterpartyAddress: '0x2eca166fea9a4585a67a8a60',
      timestamp: DateTime.now().subtract(const Duration(days: 12)),
      status: 'Confirmed',
    ),
  ];

  // Mock Chat Messages
  static final List<ChatMessage> negotiationMessages = [
    ChatMessage(
      id: 'msg_1',
      text: 'Hi there, I reviewed the pricing for the Quantum API Key. Is 299 USDC acceptable?',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      sender: 'counterparty',
      isAIHelper: false,
    ),
    ChatMessage(
      id: 'msg_2',
      text: 'ZeroPay AI analysis: Acme API listings average 270 USDC. Suggest counter-offering 275 USDC.',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      sender: 'ai',
      isAIHelper: true,
    ),
    ChatMessage(
      id: 'msg_3',
      text: 'Would you accept 275 USDC? Our transaction frequency should yield mutual savings.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      sender: 'user',
      isAIHelper: false,
    ),
  ];

  // Mock Ledger Entries
  static final List<LedgerEntry> ledgerHistory = [
    LedgerEntry(
      id: 'led_1',
      assetSymbol: 'USDC',
      amount: 12450.0,
      type: 'Debit',
      note: 'Escrow lock for Acme Corp project',
      timestamp: DateTime.now().subtract(const Duration(days: 4)),
    ),
    LedgerEntry(
      id: 'led_2',
      assetSymbol: 'USDC',
      amount: 3200.0,
      type: 'Credit',
      note: 'Revenue payout from store',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  // Mock Webhook Deliveries
  static final List<WebhookDelivery> webhookList = [
    WebhookDelivery(
      id: 'web_1',
      url: 'https://api.cryptobrews.eth/webhooks',
      event: 'escrow.released',
      statusCode: 200,
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      responseBody: '{"status":"ok"}',
    ),
  ];

  // Mock AI Recommendations
  static final List<AIRecommendation> aiRecommendationsList = [
    AIRecommendation(
      id: 'rec_1',
      category: 'Negotiation',
      title: 'Counterparty Requesting Extension',
      description: 'Developer requested a 2-day extension. Market analysis suggests granting it will improve contract security.',
      confidenceScore: 0.94,
    ),
    AIRecommendation(
      id: 'rec_2',
      category: 'Pricing',
      title: 'Artisan Blend Price Optimization',
      description: 'Market demand signals suggest increasing price of Artisan Espresso by 8% to match competitor margins.',
      confidenceScore: 0.88,
    ),
  ];
}
