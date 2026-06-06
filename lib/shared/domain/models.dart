// User Model
class User {
  final String uid;
  final String email;
  final String name;
  final String? profileImageUrl;
  final String currentRole; // 'customer' or 'merchant'
  final bool biometricsEnabled;
  final DateTime createdAt;
  final String? walletAddress;
  final String? stakeAddress;

  User({
    required this.uid,
    required this.email,
    required this.name,
    this.profileImageUrl,
    required this.currentRole,
    required this.biometricsEnabled,
    required this.createdAt,
    this.walletAddress,
    this.stakeAddress,
  });

  User copyWith({
    String? uid,
    String? email,
    String? name,
    String? profileImageUrl,
    String? currentRole,
    bool? biometricsEnabled,
    DateTime? createdAt,
    String? walletAddress,
    String? stakeAddress,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      currentRole: currentRole ?? this.currentRole,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      createdAt: createdAt ?? this.createdAt,
      walletAddress: walletAddress ?? this.walletAddress,
      stakeAddress: stakeAddress ?? this.stakeAddress,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final data = json['data'] != null ? json['data'] as Map<String, dynamic> : json;
    return User(
      uid: data['uid'] as String? ?? data['id'] as String? ?? '',
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? data['displayName'] as String? ?? '',
      profileImageUrl: data['profileImageUrl'] as String?,
      currentRole: data['currentRole'] as String? ?? data['role'] as String? ?? 'customer',
      biometricsEnabled: data['biometricsEnabled'] as bool? ?? data['biometrics_enabled'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String)
          : DateTime.now(),
      walletAddress: data['walletAddress'] as String? ?? data['wallet_address'] as String?,
      stakeAddress: data['stakeAddress'] as String? ?? data['stake_address'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'name': name,
        'profileImageUrl': profileImageUrl,
        'currentRole': currentRole,
        'biometricsEnabled': biometricsEnabled,
        'createdAt': createdAt.toIso8601String(),
        'walletAddress': walletAddress,
        'stakeAddress': stakeAddress,
      };
}

// Merchant Model
class Merchant {
  final String id;
  final String name;
  final String tier; // 'Platinum', 'Gold', 'Silver'
  final double trustScore;
  final String description;
  final String email;
  final String address;
  final Map<String, String> businessHours;
  final String logoUrl;
  final String? bannerUrl;

  Merchant({
    required this.id,
    required this.name,
    required this.tier,
    required this.trustScore,
    required this.description,
    required this.email,
    required this.address,
    required this.businessHours,
    required this.logoUrl,
    this.bannerUrl,
  });

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      id: json['id'] as String,
      name: json['name'] as String,
      tier: json['tier'] as String? ?? 'Silver',
      trustScore: (json['trustScore'] as num).toDouble(),
      description: json['description'] as String? ?? '',
      email: json['email'] as String? ?? '',
      address: json['address'] as String? ?? '',
      businessHours: Map<String, String>.from(json['businessHours'] as Map),
      logoUrl: json['logoUrl'] as String? ?? '',
      bannerUrl: json['bannerUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tier': tier,
        'trustScore': trustScore,
        'description': description,
        'email': email,
        'address': address,
        'businessHours': businessHours,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
      };
}

// Wallet Model
class Wallet {
  final String address;
  final String chainName; // 'Cardano', 'Ethereum', etc.
  final List<Asset> assets;

  Wallet({
    required this.address,
    required this.chainName,
    required this.assets,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      address: json['address'] as String,
      chainName: json['chainName'] as String,
      assets: (json['assets'] as List)
          .map((e) => Asset.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'address': address,
        'chainName': chainName,
        'assets': assets.map((e) => e.toJson()).toList(),
      };
}

// Asset Model
class Asset {
  final String symbol;
  final String name;
  final double balance;
  final double fiatValue;
  final double changePercent24h;
  final String? hexColor;

  Asset({
    required this.symbol,
    required this.name,
    required this.balance,
    required this.fiatValue,
    required this.changePercent24h,
    this.hexColor,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      balance: (json['balance'] as num).toDouble(),
      fiatValue: (json['fiatValue'] as num).toDouble(),
      changePercent24h: (json['changePercent24h'] as num).toDouble(),
      hexColor: json['hexColor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'name': name,
        'balance': balance,
        'fiatValue': fiatValue,
        'changePercent24h': changePercent24h,
        'hexColor': hexColor,
      };
}

// Milestone Model
class Milestone {
  final String id;
  final String title;
  final String description;
  final double amount;
  final String status; // 'Pending', 'In Progress', 'Released', 'Disputed'

  Milestone({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.status,
  });

  factory Milestone.fromJson(Map<String, dynamic> json) {
    return Milestone(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String? ?? 'Pending',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'amount': amount,
        'status': status,
      };
}

// Escrow Model
class Escrow {
  final String id;
  final String title;
  final String counterpartyAddress;
  final String counterpartyName;
  final double totalValue;
  final String assetSymbol;
  final String status; // 'Locked', 'Released', 'Disputed', 'Pending'
  final List<Milestone> milestones;
  final String contractAddress;
  final String chainName;
  final DateTime createdAt;
  final String? chatRoomId;
  final String? merchantStringId;
  final String? projectPlanId;

  Escrow({
    required this.id,
    required this.title,
    required this.counterpartyAddress,
    required this.counterpartyName,
    required this.totalValue,
    required this.assetSymbol,
    required this.status,
    required this.milestones,
    required this.contractAddress,
    required this.chainName,
    required this.createdAt,
    this.chatRoomId,
    this.merchantStringId,
    this.projectPlanId,
  });

  factory Escrow.fromJson(Map<String, dynamic> json) {
    return Escrow(
      id: json['id'] as String,
      title: json['title'] as String,
      counterpartyAddress: json['counterpartyAddress'] as String,
      counterpartyName: json['counterpartyName'] as String? ?? 'Unknown',
      totalValue: (json['totalValue'] as num).toDouble(),
      assetSymbol: json['assetSymbol'] as String,
      status: json['status'] as String,
      milestones: (json['milestones'] as List)
          .map((e) => Milestone.fromJson(e as Map<String, dynamic>))
          .toList(),
      contractAddress: json['contractAddress'] as String,
      chainName: json['chainName'] as String? ?? 'Cardano',
      createdAt: DateTime.parse(json['createdAt'] as String),
      chatRoomId: json['chatRoomId'] as String?,
      merchantStringId: json['merchantStringId'] as String?,
      projectPlanId: json['projectPlanId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'counterpartyAddress': counterpartyAddress,
        'counterpartyName': counterpartyName,
        'totalValue': totalValue,
        'assetSymbol': assetSymbol,
        'status': status,
        'milestones': milestones.map((e) => e.toJson()).toList(),
        'contractAddress': contractAddress,
        'chainName': chainName,
        'createdAt': createdAt.toIso8601String(),
        'chatRoomId': chatRoomId,
        'merchantStringId': merchantStringId,
        'projectPlanId': projectPlanId,
      };
}

// Juror Model
class Juror {
  final String id;
  final String name;
  final String status; // 'Active', 'Pending Vote', 'Voted'
  final bool hasVoted;

  Juror({
    required this.id,
    required this.name,
    required this.status,
    required this.hasVoted,
  });

  factory Juror.fromJson(Map<String, dynamic> json) {
    return Juror(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? 'Active',
      hasVoted: json['hasVoted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
        'hasVoted': hasVoted,
      };
}

// DisputeCase Model
class DisputeCase {
  final String caseId;
  final String title;
  final double disputedAmount;
  final String assetSymbol;
  final String plaintiffName;
  final String defendantName;
  final String status; // 'Filed', 'Evidence Gathered', 'Deliberation', 'Ruling', 'Executed'
  final DateTime filingDate;
  final double consensusLeaningCustomer; // percentage e.g. 72.0
  final List<Juror> jurors;

  DisputeCase({
    required this.caseId,
    required this.title,
    required this.disputedAmount,
    required this.assetSymbol,
    required this.plaintiffName,
    required this.defendantName,
    required this.status,
    required this.filingDate,
    required this.consensusLeaningCustomer,
    required this.jurors,
  });

  factory DisputeCase.fromJson(Map<String, dynamic> json) {
    return DisputeCase(
      caseId: json['caseId'] as String,
      title: json['title'] as String,
      disputedAmount: (json['disputedAmount'] as num).toDouble(),
      assetSymbol: json['assetSymbol'] as String? ?? 'USDC',
      plaintiffName: json['plaintiffName'] as String,
      defendantName: json['defendantName'] as String,
      status: json['status'] as String,
      filingDate: DateTime.parse(json['filingDate'] as String),
      consensusLeaningCustomer: (json['consensusLeaningCustomer'] as num).toDouble(),
      jurors: (json['jurors'] as List)
          .map((e) => Juror.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'caseId': caseId,
        'title': title,
        'disputedAmount': disputedAmount,
        'assetSymbol': assetSymbol,
        'plaintiffName': plaintiffName,
        'defendantName': defendantName,
        'status': status,
        'filingDate': filingDate.toIso8601String(),
        'consensusLeaningCustomer': consensusLeaningCustomer,
        'jurors': jurors.map((e) => e.toJson()).toList(),
      };
}

// Notification Model
class Notification {
  final String id;
  final String title;
  final String description;
  final String category; // 'Escrow', 'Security', 'Dispute', 'System'
  final DateTime timestamp;
  final bool isRead;

  Notification({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.timestamp,
    required this.isRead,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };
}

// Transaction Model
class Transaction {
  final String txHash;
  final String type; // 'Send', 'Receive', 'Escrow Lock', 'Escrow Release'
  final String assetSymbol;
  final double amount;
  final String counterpartyAddress;
  final DateTime timestamp;
  final String status; // 'Confirmed', 'Pending', 'Failed'

  Transaction({
    required this.txHash,
    required this.type,
    required this.assetSymbol,
    required this.amount,
    required this.counterpartyAddress,
    required this.timestamp,
    required this.status,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      txHash: json['txHash'] as String,
      type: json['type'] as String,
      assetSymbol: json['assetSymbol'] as String,
      amount: (json['amount'] as num).toDouble(),
      counterpartyAddress: json['counterpartyAddress'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'txHash': txHash,
        'type': type,
        'assetSymbol': assetSymbol,
        'amount': amount,
        'counterpartyAddress': counterpartyAddress,
        'timestamp': timestamp.toIso8601String(),
        'status': status,
      };
}

// ChatMessage Model
class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final String sender; // 'user', 'ai', 'counterparty'
  final bool isAIHelper;

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.sender,
    required this.isAIHelper,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sender: json['sender'] as String,
      isAIHelper: json['isAIHelper'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'sender': sender,
        'isAIHelper': isAIHelper,
      };
}

// WebhookDelivery Model
class WebhookDelivery {
  final String id;
  final String url;
  final String event; // 'escrow.created', 'escrow.released', 'dispute.filed'
  final int statusCode;
  final DateTime timestamp;
  final String responseBody;

  WebhookDelivery({
    required this.id,
    required this.url,
    required this.event,
    required this.statusCode,
    required this.timestamp,
    required this.responseBody,
  });

  factory WebhookDelivery.fromJson(Map<String, dynamic> json) {
    return WebhookDelivery(
      id: json['id'] as String,
      url: json['url'] as String,
      event: json['event'] as String,
      statusCode: json['statusCode'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      responseBody: json['responseBody'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'event': event,
        'statusCode': statusCode,
        'timestamp': timestamp.toIso8601String(),
        'responseBody': responseBody,
      };
}

// LedgerEntry Model
class LedgerEntry {
  final String id;
  final String assetSymbol;
  final double amount;
  final String type; // 'Credit', 'Debit'
  final String note;
  final DateTime timestamp;

  LedgerEntry({
    required this.id,
    required this.assetSymbol,
    required this.amount,
    required this.type,
    required this.note,
    required this.timestamp,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: json['id'] as String,
      assetSymbol: json['assetSymbol'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] as String,
      note: json['note'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetSymbol': assetSymbol,
        'amount': amount,
        'type': type,
        'note': note,
        'timestamp': timestamp.toIso8601String(),
      };
}

// AIRecommendation Model
class AIRecommendation {
  final String id;
  final String category; // 'Pricing', 'Negotiation', 'Dispute', 'Security'
  final String title;
  final String description;
  final double confidenceScore; // e.g. 0.92 (92%)
  final Map<String, dynamic>? metaData;

  AIRecommendation({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.confidenceScore,
    this.metaData,
  });

  factory AIRecommendation.fromJson(Map<String, dynamic> json) {
    return AIRecommendation(
      id: json['id'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      confidenceScore: (json['confidenceScore'] as num).toDouble(),
      metaData: json['metaData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'title': title,
        'description': description,
        'confidenceScore': confidenceScore,
        'metaData': metaData,
      };
}

class GithubAuditReqs {
  final List<String> requiredFiles;
  final List<String> requiredFeatures;
  final List<String> requiredTests;
  final List<String> requiredDocumentation;

  GithubAuditReqs({
    required this.requiredFiles,
    required this.requiredFeatures,
    required this.requiredTests,
    required this.requiredDocumentation,
  });

  factory GithubAuditReqs.fromJson(Map<String, dynamic> json) {
    return GithubAuditReqs(
      requiredFiles: List<String>.from(json['requiredFiles'] ?? []),
      requiredFeatures: List<String>.from(json['requiredFeatures'] ?? []),
      requiredTests: List<String>.from(json['requiredTests'] ?? []),
      requiredDocumentation: List<String>.from(json['requiredDocumentation'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'requiredFiles': requiredFiles,
        'requiredFeatures': requiredFeatures,
        'requiredTests': requiredTests,
        'requiredDocumentation': requiredDocumentation,
      };
}

class ProjectPlanMilestone {
  final String milestoneId;
  final String title;
  final String description;
  final int amountPaise;
  final String status;
  final GithubAuditReqs githubAuditRequirements;

  ProjectPlanMilestone({
    required this.milestoneId,
    required this.title,
    required this.description,
    required this.amountPaise,
    required this.status,
    required this.githubAuditRequirements,
  });

  factory ProjectPlanMilestone.fromJson(Map<String, dynamic> json) {
    return ProjectPlanMilestone(
      milestoneId: json['milestoneId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amountPaise: json['amountPaise'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      githubAuditRequirements: json['githubAuditRequirements'] != null
          ? GithubAuditReqs.fromJson(json['githubAuditRequirements'] as Map<String, dynamic>)
          : GithubAuditReqs(requiredFiles: [], requiredFeatures: [], requiredTests: [], requiredDocumentation: []),
    );
  }

  Map<String, dynamic> toJson() => {
        'milestoneId': milestoneId,
        'title': title,
        'description': description,
        'amountPaise': amountPaise,
        'status': status,
        'githubAuditRequirements': githubAuditRequirements.toJson(),
      };
}

class ProjectTask {
  final String taskId;
  final String title;
  final String description;
  final int estimatedHours;
  final String priority;
  final List<String> acceptanceCriteria;
  final GithubAuditReqs githubAuditRequirements;

  ProjectTask({
    required this.taskId,
    required this.title,
    required this.description,
    required this.estimatedHours,
    required this.priority,
    required this.acceptanceCriteria,
    required this.githubAuditRequirements,
  });

  factory ProjectTask.fromJson(Map<String, dynamic> json) {
    return ProjectTask(
      taskId: json['taskId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      estimatedHours: json['estimatedHours'] as int? ?? 0,
      priority: json['priority'] as String? ?? 'medium',
      acceptanceCriteria: List<String>.from(json['acceptanceCriteria'] ?? []),
      githubAuditRequirements: json['githubAuditRequirements'] != null
          ? GithubAuditReqs.fromJson(json['githubAuditRequirements'] as Map<String, dynamic>)
          : GithubAuditReqs(requiredFiles: [], requiredFeatures: [], requiredTests: [], requiredDocumentation: []),
    );
  }

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'title': title,
        'description': description,
        'estimatedHours': estimatedHours,
        'priority': priority,
        'acceptanceCriteria': acceptanceCriteria,
        'githubAuditRequirements': githubAuditRequirements.toJson(),
      };
}

class RequirementTraceability {
  final String requirementId;
  final String requirement;
  final List<String> milestoneIds;
  final List<String> taskIds;
  final GithubAuditReqs githubAuditRequirements;

  RequirementTraceability({
    required this.requirementId,
    required this.requirement,
    required this.milestoneIds,
    required this.taskIds,
    required this.githubAuditRequirements,
  });

  factory RequirementTraceability.fromJson(Map<String, dynamic> json) {
    return RequirementTraceability(
      requirementId: json['requirementId'] as String? ?? '',
      requirement: json['requirement'] as String? ?? '',
      milestoneIds: List<String>.from(json['milestoneIds'] ?? []),
      taskIds: List<String>.from(json['taskIds'] ?? []),
      githubAuditRequirements: json['githubAuditRequirements'] != null
          ? GithubAuditReqs.fromJson(json['githubAuditRequirements'] as Map<String, dynamic>)
          : GithubAuditReqs(requiredFiles: [], requiredFeatures: [], requiredTests: [], requiredDocumentation: []),
    );
  }

  Map<String, dynamic> toJson() => {
        'requirementId': requirementId,
        'requirement': requirement,
        'milestoneIds': milestoneIds,
        'taskIds': taskIds,
        'githubAuditRequirements': githubAuditRequirements.toJson(),
      };
}

class RequirementTrace {
  final String requirement;
  final List<String> linkedMilestones;
  final List<String> linkedTasks;

  RequirementTrace({
    required this.requirement,
    required this.linkedMilestones,
    required this.linkedTasks,
  });

  factory RequirementTrace.fromJson(Map<String, dynamic> json) {
    return RequirementTrace(
      requirement: json['requirement'] as String? ?? '',
      linkedMilestones: List<String>.from(json['linkedMilestones'] ?? []),
      linkedTasks: List<String>.from(json['linkedTasks'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'requirement': requirement,
        'linkedMilestones': linkedMilestones,
        'linkedTasks': linkedTasks,
      };
}

class BudgetCategory {
  final String category;
  final int percentage;
  final int amountPaise;

  BudgetCategory({
    required this.category,
    required this.percentage,
    required this.amountPaise,
  });

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    return BudgetCategory(
      category: json['category'] as String? ?? '',
      percentage: json['percentage'] as int? ?? 0,
      amountPaise: json['amountPaise'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'percentage': percentage,
        'amountPaise': amountPaise,
      };
}

class ProjectPlan {
  final String planId;
  final int version;
  final String merchantId;
  final String? customerId;
  final String? invoiceId;
  final String requirements;
  final String projectSummary;
  final String scope;
  final List<ProjectPlanMilestone> milestones;
  final List<ProjectTask> tasks;
  final List<RequirementTrace> requirementsBreakdown;
  final List<RequirementTraceability> requirementTrace;
  final int optimisticDays;
  final int realisticDays;
  final int conservativeDays;
  final String timelineSummary;
  final List<String> acceptanceCriteria;
  final List<String> riskFactors;
  final int planningConfidence;
  final List<String> assumptions;
  final List<String> unknowns;
  final List<BudgetCategory> budgetAllocation;
  final String escrowStructure;
  final String escrowRationale;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? repositoryUrl;
  final String? repositoryOwner;
  final String? repositoryName;
  final String? branch;

  ProjectPlan({
    required this.planId,
    required this.version,
    required this.merchantId,
    this.customerId,
    this.invoiceId,
    required this.requirements,
    required this.projectSummary,
    required this.scope,
    required this.milestones,
    required this.tasks,
    required this.requirementsBreakdown,
    required this.requirementTrace,
    required this.optimisticDays,
    required this.realisticDays,
    required this.conservativeDays,
    required this.timelineSummary,
    required this.acceptanceCriteria,
    required this.riskFactors,
    required this.planningConfidence,
    required this.assumptions,
    required this.unknowns,
    required this.budgetAllocation,
    required this.escrowStructure,
    required this.escrowRationale,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.repositoryUrl,
    this.repositoryOwner,
    this.repositoryName,
    this.branch,
  });

  factory ProjectPlan.fromJson(Map<String, dynamic> json) {
    final data = json['data'] != null ? json['data'] as Map<String, dynamic> : json;
    
    final timelineObj = data['timeline'] as Map<String, dynamic>? ?? {};
    final escrowObj = data['escrowPlan'] as Map<String, dynamic>? ?? {};

    return ProjectPlan(
      planId: data['planId'] as String? ?? '',
      version: data['version'] as int? ?? 1,
      merchantId: data['merchantId'] as String? ?? '',
      customerId: data['customerId'] as String?,
      invoiceId: data['invoiceId'] as String?,
      requirements: data['requirements'] as String? ?? '',
      projectSummary: data['projectSummary'] as String? ?? '',
      scope: data['scope'] as String? ?? '',
      milestones: (data['milestones'] as List? ?? [])
          .map((e) => ProjectPlanMilestone.fromJson(e as Map<String, dynamic>))
          .toList(),
      tasks: (data['tasks'] as List? ?? [])
          .map((e) => ProjectTask.fromJson(e as Map<String, dynamic>))
          .toList(),
      requirementsBreakdown: (data['requirementsBreakdown'] as List? ?? [])
          .map((e) => RequirementTrace.fromJson(e as Map<String, dynamic>))
          .toList(),
      requirementTrace: (data['requirementTrace'] as List? ?? [])
          .map((e) => RequirementTraceability.fromJson(e as Map<String, dynamic>))
          .toList(),
      optimisticDays: timelineObj['optimisticDays'] as int? ?? 0,
      realisticDays: timelineObj['realisticDays'] as int? ?? 0,
      conservativeDays: timelineObj['conservativeDays'] as int? ?? 0,
      timelineSummary: timelineObj['summary'] as String? ?? '',
      acceptanceCriteria: List<String>.from(data['acceptanceCriteria'] ?? []),
      riskFactors: List<String>.from(data['riskFactors'] ?? []),
      planningConfidence: data['planningConfidence'] as int? ?? 0,
      assumptions: List<String>.from(data['assumptions'] ?? []),
      unknowns: List<String>.from(data['unknowns'] ?? []),
      budgetAllocation: (data['budgetAllocation'] as List? ?? [])
          .map((e) => BudgetCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      escrowStructure: escrowObj['structure'] as String? ?? '',
      escrowRationale: escrowObj['rationale'] as String? ?? '',
      status: data['status'] as String? ?? 'Draft',
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt'] as String) : DateTime.now(),
      updatedAt: data['updatedAt'] != null ? DateTime.parse(data['updatedAt'] as String) : DateTime.now(),
      repositoryUrl: data['repositoryUrl'] as String? ?? data['repository_url'] as String?,
      repositoryOwner: data['repositoryOwner'] as String? ?? data['repository_owner'] as String?,
      repositoryName: data['repositoryName'] as String? ?? data['repository_name'] as String?,
      branch: data['branch'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'planId': planId,
        'version': version,
        'merchantId': merchantId,
        'customerId': customerId,
        'invoiceId': invoiceId,
        'requirements': requirements,
        'projectSummary': projectSummary,
        'scope': scope,
        'milestones': milestones.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'requirementsBreakdown': requirementsBreakdown.map((e) => e.toJson()).toList(),
        'requirementTrace': requirementTrace.map((e) => e.toJson()).toList(),
        'timeline': {
          'optimisticDays': optimisticDays,
          'realisticDays': realisticDays,
          'conservativeDays': conservativeDays,
          'summary': timelineSummary,
        },
        'acceptanceCriteria': acceptanceCriteria,
        'riskFactors': riskFactors,
        'planningConfidence': planningConfidence,
        'assumptions': assumptions,
        'unknowns': unknowns,
        'budgetAllocation': budgetAllocation.map((e) => e.toJson()).toList(),
        'escrowPlan': {
          'structure': escrowStructure,
          'rationale': escrowRationale,
        },
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'repositoryUrl': repositoryUrl,
        'repositoryOwner': repositoryOwner,
        'repositoryName': repositoryName,
        'branch': branch,
      };
}

