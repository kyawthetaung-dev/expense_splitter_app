import 'package:expense_splitter_app/models/expense_payer.dart';
import 'package:expense_splitter_app/models/expense_share.dart';
import 'package:expense_splitter_app/models/participant.dart';
import 'package:expense_splitter_app/models/person_balance.dart';
import 'package:expense_splitter_app/services/balance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/kta_uks_ast_ksdl_scenario.dart';

void main() {
  group('calculatePersonBalances', () {
    test('matches the spec example exactly', () {
      final balances = calculatePersonBalances(
        participants: KtaUksAstKsdlScenario.participants,
        allPayers: KtaUksAstKsdlScenario.payers,
        allShares: KtaUksAstKsdlScenario.shares,
      );
      final byId = {for (final b in balances) b.participantId: b};

      expect(byId[KtaUksAstKsdlScenario.kta]!.totalShare, 17025);
      expect(byId[KtaUksAstKsdlScenario.kta]!.totalPaid, 5000);
      expect(byId[KtaUksAstKsdlScenario.kta]!.balance, -12025);
      expect(byId[KtaUksAstKsdlScenario.kta]!.status, BalanceStatus.pay);

      expect(byId[KtaUksAstKsdlScenario.uks]!.balance, -17025);
      expect(byId[KtaUksAstKsdlScenario.uks]!.status, BalanceStatus.pay);

      expect(byId[KtaUksAstKsdlScenario.ast]!.balance, -17025);
      expect(byId[KtaUksAstKsdlScenario.ast]!.status, BalanceStatus.pay);

      expect(byId[KtaUksAstKsdlScenario.ksdl]!.totalShare, 7025);
      expect(byId[KtaUksAstKsdlScenario.ksdl]!.totalPaid, 53100);
      expect(byId[KtaUksAstKsdlScenario.ksdl]!.balance, 46075);
      expect(byId[KtaUksAstKsdlScenario.ksdl]!.status, BalanceStatus.receive);
    });

    test('payer who is not a share-participant on that expense still counts toward totalPaid', () {
      final balances = calculatePersonBalances(
        participants: KtaUksAstKsdlScenario.participants,
        allPayers: KtaUksAstKsdlScenario.payers,
        allShares: KtaUksAstKsdlScenario.shares,
      );
      final ksdl = balances.firstWhere((b) => b.participantId == KtaUksAstKsdlScenario.ksdl);
      expect(ksdl.totalPaid, 53100);
    });

    test('participant with no activity at all is settled at zero', () {
      const participants = [
        Participant(id: 'a', groupId: 'g', name: 'A'),
        Participant(id: 'b', groupId: 'g', name: 'B'),
      ];
      final balances = calculatePersonBalances(
        participants: participants,
        allPayers: const [],
        allShares: const [],
      );
      expect(
        balances,
        everyElement(
          predicate<PersonBalance>((b) => b.balance == 0 && b.status == BalanceStatus.settled),
        ),
      );
    });

    test('single participant: paid equals share -> settled', () {
      const participants = [Participant(id: 'solo', groupId: 'g', name: 'Solo')];
      const payers = [ExpensePayer(id: 'p', expenseId: 'e', participantId: 'solo', paidAmount: 500)];
      const shares = [ExpenseShare(id: 's', expenseId: 'e', participantId: 'solo', shareAmount: 500)];
      final balances = calculatePersonBalances(
        participants: participants,
        allPayers: payers,
        allShares: shares,
      );
      expect(balances.single.status, BalanceStatus.settled);
    });

    test('duplicate participant names are fine — distinguished by id', () {
      const participants = [
        Participant(id: 'p1', groupId: 'g', name: 'Alex'),
        Participant(id: 'p2', groupId: 'g', name: 'Alex'),
      ];
      const shares = [
        ExpenseShare(id: 's1', expenseId: 'e', participantId: 'p1', shareAmount: 100),
        ExpenseShare(id: 's2', expenseId: 'e', participantId: 'p2', shareAmount: 200),
      ];
      final balances = calculatePersonBalances(
        participants: participants,
        allPayers: const [],
        allShares: shares,
      );
      final byId = {for (final b in balances) b.participantId: b.totalShare};
      expect(byId, {'p1': 100, 'p2': 200});
    });

    test('multiple payers on one expense: 100,000 paid 60,000+40,000, split among 4', () {
      const participants = [
        Participant(id: 'kta', groupId: 'g', name: 'KTA'),
        Participant(id: 'uks', groupId: 'g', name: 'UKS'),
        Participant(id: 'ast', groupId: 'g', name: 'AST'),
        Participant(id: 'ksdl', groupId: 'g', name: 'KSDL'),
      ];
      const payers = [
        ExpensePayer(id: 'p1', expenseId: 'e', participantId: 'kta', paidAmount: 60000),
        ExpensePayer(id: 'p2', expenseId: 'e', participantId: 'uks', paidAmount: 40000),
      ];
      const shares = [
        ExpenseShare(id: 's1', expenseId: 'e', participantId: 'kta', shareAmount: 25000),
        ExpenseShare(id: 's2', expenseId: 'e', participantId: 'uks', shareAmount: 25000),
        ExpenseShare(id: 's3', expenseId: 'e', participantId: 'ast', shareAmount: 25000),
        ExpenseShare(id: 's4', expenseId: 'e', participantId: 'ksdl', shareAmount: 25000),
      ];
      final balances = calculatePersonBalances(
        participants: participants,
        allPayers: payers,
        allShares: shares,
      );
      final byId = {for (final b in balances) b.participantId: b.balance};
      expect(byId['kta'], 35000);
      expect(byId['uks'], 15000);
      expect(byId['ast'], -25000);
      expect(byId['ksdl'], -25000);
    });
  });
}
