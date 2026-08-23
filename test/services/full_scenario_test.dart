import 'package:expense_splitter_app/models/expense_share.dart';
import 'package:expense_splitter_app/models/person_balance.dart';
import 'package:expense_splitter_app/models/split_type.dart';
import 'package:expense_splitter_app/services/balance_calculator.dart';
import 'package:expense_splitter_app/services/expense_share_calculator.dart';
import 'package:expense_splitter_app/services/settlement_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/kta_uks_ast_ksdl_scenario.dart';

/// End-to-end pipeline test for the canonical spec scenario: computes
/// shares for all three expenses via calculateExpenseShares, feeds them
/// into calculatePersonBalances alongside the stated paid amounts, then
/// into calculateSettlements — asserting the exact numbers from the spec
/// at every stage, exactly as required by the spec's calculation-testing
/// section.
void main() {
  test('KTA/UKS/AST/KSDL scenario matches the spec exactly end-to-end', () {
    final shares = <ExpenseShare>[];
    var nextId = 0;
    void addShares(String expenseId, int totalAmount, List<String> participantIds) {
      final computed = calculateExpenseShares(
        totalAmount: totalAmount,
        splitType: SplitType.equal,
        participantIds: participantIds,
      );
      for (final s in computed) {
        shares.add(
          ExpenseShare(
            id: 's${nextId++}',
            expenseId: expenseId,
            participantId: s.participantId,
            shareAmount: s.shareAmount,
          ),
        );
      }
    }

    addShares('e-pool', 30000, KtaUksAstKsdlScenario.swimmingPoolParticipantIds);
    addShares('e-bbq', 8500, KtaUksAstKsdlScenario.allParticipantIds);
    addShares('e-gg', 19600, KtaUksAstKsdlScenario.allParticipantIds);

    final balances = calculatePersonBalances(
      participants: KtaUksAstKsdlScenario.participants,
      allPayers: KtaUksAstKsdlScenario.payers,
      allShares: shares,
    );
    final byId = {for (final b in balances) b.participantId: b};

    expect(byId[KtaUksAstKsdlScenario.kta]!.totalShare, 17025);
    expect(byId[KtaUksAstKsdlScenario.uks]!.totalShare, 17025);
    expect(byId[KtaUksAstKsdlScenario.ast]!.totalShare, 17025);
    expect(byId[KtaUksAstKsdlScenario.ksdl]!.totalShare, 7025);

    expect(byId[KtaUksAstKsdlScenario.kta]!.balance, -12025);
    expect(byId[KtaUksAstKsdlScenario.uks]!.balance, -17025);
    expect(byId[KtaUksAstKsdlScenario.ast]!.balance, -17025);
    expect(byId[KtaUksAstKsdlScenario.ksdl]!.balance, 46075);

    expect(byId[KtaUksAstKsdlScenario.kta]!.status, BalanceStatus.pay);
    expect(byId[KtaUksAstKsdlScenario.uks]!.status, BalanceStatus.pay);
    expect(byId[KtaUksAstKsdlScenario.ast]!.status, BalanceStatus.pay);
    expect(byId[KtaUksAstKsdlScenario.ksdl]!.status, BalanceStatus.receive);

    final settlements = calculateSettlements(balances: balances);
    expect(settlements, hasLength(3));
    expect(
      settlements.every((t) => t.toParticipantId == KtaUksAstKsdlScenario.ksdl),
      isTrue,
    );
    final byFrom = {for (final t in settlements) t.fromParticipantId: t.amount};
    expect(byFrom, {
      KtaUksAstKsdlScenario.kta: 12025,
      KtaUksAstKsdlScenario.uks: 17025,
      KtaUksAstKsdlScenario.ast: 17025,
    });
  });
}
