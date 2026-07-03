import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:zeropay/shared/domain/models.dart';
import 'package:zeropay/core/api/api_client.dart';
import 'package:zeropay/core/api/api_services.dart';

void main() {
  group('ZeroPay Model Serialization Baseline Tests', () {
    test('User JSON Serialization/Deserialization', () {
      final now = DateTime.now();
      final user = User(
        uid: 'user_123',
        email: 'test@zeropay.io',
        name: 'John Doe',
        profileImageUrl: 'https://avatar.io/1',
        currentRole: 'customer',
        biometricsEnabled: true,
        createdAt: now,
      );

      final json = user.toJson();
      expect(json['uid'], 'user_123');
      expect(json['email'], 'test@zeropay.io');
      expect(json['biometricsEnabled'], true);

      final parsed = User.fromJson(json);
      expect(parsed.uid, 'user_123');
      expect(parsed.email, 'test@zeropay.io');
      expect(parsed.name, 'John Doe');
      expect(parsed.currentRole, 'customer');
      expect(parsed.biometricsEnabled, true);
    });

    test('Asset JSON Serialization/Deserialization', () {
      final asset = Asset(
        symbol: 'ADA',
        name: 'Cardano',
        balance: 1000.5,
        fiatValue: 400.2,
        changePercent24h: 2.5,
        hexColor: '0xFF0033AD',
      );

      final json = asset.toJson();
      expect(json['symbol'], 'ADA');
      expect(json['balance'], 1000.5);

      final parsed = Asset.fromJson(json);
      expect(parsed.symbol, 'ADA');
      expect(parsed.name, 'Cardano');
      expect(parsed.balance, 1000.5);
      expect(parsed.fiatValue, 400.2);
    });

    test('Milestone JSON Serialization/Deserialization', () {
      final milestone = Milestone(
        id: 'ms_1',
        title: 'Design Phase',
        description: 'Provide Figma mockups',
        amount: 250.0,
        status: 'Released',
      );

      final json = milestone.toJson();
      expect(json['id'], 'ms_1');
      expect(json['amount'], 250.0);

      final parsed = Milestone.fromJson(json);
      expect(parsed.id, 'ms_1');
      expect(parsed.title, 'Design Phase');
      expect(parsed.amount, 250.0);
      expect(parsed.status, 'Released');
    });

    test('Escrow JSON Serialization/Deserialization', () {
      final now = DateTime.now();
      final escrow = Escrow(
        id: 'esc_999',
        title: 'Website Development',
        counterpartyAddress: 'addr1q...xyz',
        counterpartyName: 'Alice Dev',
        totalValue: 500.0,
        assetSymbol: 'USDC',
        status: 'Locked',
        milestones: [
          Milestone(id: 'ms_1', title: 'Milestone 1', description: 'desc', amount: 500.0, status: 'Pending'),
        ],
        contractAddress: 'addr1escrow...123',
        chainName: 'Cardano',
        createdAt: now,
      );

      final json = escrow.toJson();
      expect(json['id'], 'esc_999');
      expect(json['totalValue'], 500.0);

      final parsed = Escrow.fromJson(json);
      expect(parsed.id, 'esc_999');
      expect(parsed.title, 'Website Development');
      expect(parsed.milestones.length, 1);
      expect(parsed.milestones.first.id, 'ms_1');
    });

    test('DisputeCase JSON Serialization/Deserialization', () {
      final now = DateTime.now();
      final dispute = DisputeCase(
        caseId: 'DS-9281',
        title: 'Cargo Manifest Dispute',
        disputedAmount: 1500.0,
        assetSymbol: 'USDC',
        plaintiffName: 'Bob Corp',
        defendantName: 'Alice Logistics',
        status: 'Deliberation',
        filingDate: now,
        consensusLeaningCustomer: 72.0,
        jurors: [
          Juror(id: 'jur_1', name: 'Jury Member 1', status: 'Active', hasVoted: true),
        ],
      );

      final json = dispute.toJson();
      expect(json['caseId'], 'DS-9281');
      expect(json['consensusLeaningCustomer'], 72.0);

      final parsed = DisputeCase.fromJson(json);
      expect(parsed.caseId, 'DS-9281');
      expect(parsed.title, 'Cargo Manifest Dispute');
      expect(parsed.jurors.length, 1);
      expect(parsed.jurors.first.hasVoted, true);
    });

    test('ProjectPlan JSON Deserialization', () {
      final mockPlanJson = {
        "planId": "PLAN-20260607-K60Q0K",
        "version": 1,
        "requirements": "Build a web app",
        "projectSummary": "Develop a web app summary",
        "scope": "Develop a web app scope",
        "milestones": [
          {
            "milestoneId": "MS-20260607-M5V39X",
            "title": "Project Initiation & Frontend Development",
            "description": "Setup project infrastructure, develop frontend.",
            "amountPaise": 100000,
            "status": "pending",
            "timelineEstimateOptimisticDays": 4,
            "timelineEstimateRealisticDays": 5,
            "timelineEstimateConservativeDays": 7,
            "deliverables": ["Project Repo", "Frontend Build"],
            "validationCriteria": ["Successful Build", "Basic UI Functional"],
            "successConditions": ["Code Review", "Basic Testing"],
            "githubAuditRequirements": {
              "requiredFiles": ["package.json", "frontend tests"],
              "requiredFeatures": [],
              "requiredTests": [],
              "requiredDocumentation": []
            }
          }
        ],
        "tasks": [
          {
            "taskId": "TSK-20260607-ZCTXFS",
            "title": "Setup Project Infrastructure",
            "description": "Initialize Git, setup CI/CD pipelines.",
            "estimatedHours": 4,
            "priority": "high",
            "acceptanceCriteria": ["Functional CI/CD"],
            "githubAuditRequirements": {
              "requiredFiles": [".github/workflows"],
              "requiredFeatures": [],
              "requiredTests": [],
              "requiredDocumentation": []
            }
          }
        ],
        "requirementsBreakdown": [
          {
            "requirement": "User Registration and Login System",
            "linkedMilestones": ["MS-20260607-M5V39X"],
            "linkedTasks": ["TSK-20260607-ZCTXFS"]
          }
        ],
        "requirementTrace": [
          {
            "requirementId": "REQ-001",
            "requirement": "User Registration and Login System",
            "milestoneIds": ["MS-20260607-M5V39X"],
            "taskIds": ["TSK-20260607-ZCTXFS"],
            "githubAuditRequirements": {
              "requiredFiles": [".github/workflows"],
              "requiredFeatures": [],
              "requiredTests": [],
              "requiredDocumentation": []
            }
          }
        ],
        "timeline": {
          "optimisticDays": 15,
          "realisticDays": 20,
          "conservativeDays": 25,
          "summary": "Project timeline summary"
        },
        "acceptanceCriteria": ["Fully Functional Web Application", "User Satisfaction Survey Positive"],
        "riskFactors": ["[HIGH] Delayed Backend Development"],
        "planningConfidence": 100,
        "assumptions": ["Standard hardware"],
        "unknowns": ["Third-party API rate limits"],
        "budgetAllocation": [
          {
            "category": "Project Initiation & Frontend Development",
            "percentage": 20,
            "amountPaise": 100000
          }
        ],
        "escrowPlan": {
          "structure": "Milestone-based progressive release escrow structure.",
          "rationale": "Funds are released progressively"
        },
        "status": "AI Generated",
        "createdAt": "2026-06-07T02:43:15.053Z",
        "updatedAt": "2026-06-07T02:43:15.053Z"
      };

      final plan = ProjectPlan.fromJson(mockPlanJson);
      expect(plan.planId, "PLAN-20260607-K60Q0K");
      expect(plan.milestones.length, 1);
      expect(plan.milestones.first.githubAuditRequirements.requiredFiles.first, "package.json");
    });

    test('Real API Call to /projects/plan Integration Test', () async {
      final fakeStorage = FakeSecureStorage();
      await fakeStorage.write(key: 'auth_jwt_token', value: 'dev_token_merchant');
      
      final customDio = Dio(BaseOptions(
        baseUrl: 'http://localhost:9999/api/v1',
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
      ));
      
      final client = BaseApiClient(dio: customDio, storage: fakeStorage);
      final projectService = ProjectApiService(client);
      
      debugPrint('[Test] Initiating API call to offline local server (port 9999)...');
      final stopwatch = Stopwatch()..start();
      try {
        final response = await projectService.generateProjectPlan(
          requirements: 'Build a simple website',
          totalAmountPaise: 500000,
        );
        debugPrint('[Test] API call returned: ${response.statusCode}');
      } catch (e, stack) {
        debugPrint('[Test] API call threw error after ${stopwatch.elapsedMilliseconds}ms: $e');
        debugPrint('[Test] StackTrace: $stack');
      }
    }, timeout: const Timeout(Duration(seconds: 120)));
  });
}

class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};
  
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read) {
      final key = invocation.namedArguments[#key] as String;
      return Future.value(_data[key]);
    }
    if (invocation.memberName == #write) {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String;
      _data[key] = value;
      return Future.value();
    }
    if (invocation.memberName == #delete) {
      final key = invocation.namedArguments[#key] as String;
      _data.remove(key);
      return Future.value();
    }
    return null;
  }
}
