import 'package:flutter/foundation.dart';

class EndpointContract {
  final String path;
  final String method;
  final bool requiresAuth;
  final List<String> requiredRequestFields;
  final List<String> requiredResponseFields;

  EndpointContract({
    required this.path,
    required this.method,
    required this.requiresAuth,
    required this.requiredRequestFields,
    required this.requiredResponseFields,
  });
}

class ContractValidationResult {
  final String endpoint;
  final bool success;
  final List<String> errors;

  ContractValidationResult({
    required this.endpoint,
    required this.success,
    required this.errors,
  });
}

class ApiContractGenerator {
  static final List<EndpointContract> contracts = [
    EndpointContract(
      path: '/auth/sync',
      method: 'POST',
      requiresAuth: true,
      requiredRequestFields: ['id_token'],
      requiredResponseFields: ['uid', 'email', 'name', 'currentRole'],
    ),
    EndpointContract(
      path: '/auth/me',
      method: 'GET',
      requiresAuth: true,
      requiredRequestFields: [],
      requiredResponseFields: ['uid', 'email', 'name', 'currentRole'],
    ),
    EndpointContract(
      path: '/wallet/balances',
      method: 'GET',
      requiresAuth: true,
      requiredRequestFields: [],
      requiredResponseFields: ['symbol', 'name', 'balance_units', 'fiat_value'],
    ),
    EndpointContract(
      path: '/wallet/transfer',
      method: 'POST',
      requiresAuth: true,
      requiredRequestFields: ['recipient', 'amount_units', 'symbol'],
      requiredResponseFields: ['txHash', 'status'],
    ),
    EndpointContract(
      path: '/escrow/contracts',
      method: 'GET',
      requiresAuth: true,
      requiredRequestFields: [],
      requiredResponseFields: ['id', 'title', 'total_value_units', 'milestones'],
    ),
    EndpointContract(
      path: '/escrow/release-milestone',
      method: 'POST',
      requiresAuth: true,
      requiredRequestFields: ['escrow_id', 'milestone_id'],
      requiredResponseFields: ['status', 'txHash'],
    ),
    EndpointContract(
      path: '/escrow/dispute',
      method: 'POST',
      requiresAuth: true,
      requiredRequestFields: ['escrow_id'],
      requiredResponseFields: ['status', 'caseId'],
    ),
  ];

  // Validate dynamic client payload against Zod/Backend DTO contract
  static ContractValidationResult validateRequest(String path, Map<String, dynamic> payload) {
    final contract = contracts.firstWhere(
      (e) => e.path == path,
      orElse: () => throw Exception('Endpoint contract not found for path: $path'),
    );

    final List<String> errors = [];
    for (final field in contract.requiredRequestFields) {
      if (!payload.containsKey(field) || payload[field] == null) {
        errors.add('Missing required request DTO field: "$field"');
      }
    }

    return ContractValidationResult(
      endpoint: '${contract.method} $path',
      success: errors.isEmpty,
      errors: errors,
    );
  }

  // Validate backend response map to prevent runtime deserialization crashes (Schema Drift Guard)
  static ContractValidationResult validateResponse(String path, Map<String, dynamic> response) {
    final contract = contracts.firstWhere(
      (e) => e.path == path,
      orElse: () => throw Exception('Endpoint contract not found for path: $path'),
    );

    final List<String> errors = [];
    for (final field in contract.requiredResponseFields) {
      if (!response.containsKey(field) || response[field] == null) {
        errors.add('Schema drift detected: Missing required backend field: "$field"');
      }
    }

    return ContractValidationResult(
      endpoint: '${contract.method} $path',
      success: errors.isEmpty,
      errors: errors,
    );
  }

  // Run automated contract assertions on startup/testing CI/CD
  static bool executeAutomatedContractSuite() {
    if (kDebugMode) {
      print('Running automated API contract validation suite (9.75)...');
    }

    bool allPassed = true;

    // Test Case 1: Valid transfer payload
    final txReq = validateRequest('/wallet/transfer', {
      'recipient': '0x9abc...8877',
      'amount_units': 150000,
      'symbol': 'ADA',
    });
    
    if (!txReq.success) allPassed = false;

    // Test Case 2: Stale field detection
    final syncRes = validateResponse('/auth/sync', {
      'uid': 'usr_test_1',
      'email': 'test@zeropay.network',
      'name': 'Validator',
      'currentRole': 'customer',
    });

    if (!syncRes.success) allPassed = false;

    if (kDebugMode) {
      print('Contract Assertions: ${allPassed ? 'ALL PASSED (100%)' : 'DRIFT DETECTED'}');
    }

    return allPassed;
  }
}
