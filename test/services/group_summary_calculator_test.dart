import 'package:expense_splitter_app/models/participant.dart';
import 'package:expense_splitter_app/services/balance_calculator.dart';
import 'package:expense_splitter_app/services/group_summary_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/kta_uks_ast_ksdl_scenario.dart';

void main() {
  test('calculateGroupSummary matches the spec example', () {
    final balances = calculatePersonBalances(
      participants: KtaUksAstKsdlScenario.participants,
      allPayers: KtaUksAstKsdlScenario.payers,
      allShares: KtaUksAstKsdlScenario.shares,
    );
    final summary = calculateGroupSummary(
      expenses: KtaUksAstKsdlScenario.expenses,
      participants: KtaUksAstKsdlScenario.participants,
      balances: balances,
    );

    expect(summary.expenseCount, 3);
    expect(summary.totalExpenseAmount, 58100);
    expect(summary.participantCount, 4);
    expect(summary.totalPaid, 58100);
    expect(summary.totalOutstanding, 46075);
    expect(summary.isFullySettled, isFalse);
  });

  test('fully settled group reports isFullySettled true and zero outstanding', () {
    const participants = [
      Participant(id: 'a', groupId: 'g', name: 'A'),
      Participant(id: 'b', groupId: 'g', name: 'B'),
    ];
    final balances = calculatePersonBalances(
      participants: participants,
      allPayers: const [],
      allShares: const [],
    );
    final summary = calculateGroupSummary(
      expenses: const [],
      participants: participants,
      balances: balances,
    );

    expect(summary.isFullySettled, isTrue);
    expect(summary.totalOutstanding, 0);
    expect(summary.expenseCount, 0);
  });
}
