import 'package:flutter_test/flutter_test.dart';
import 'package:zeropay/shared/domain/models.dart';

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
  });
}
