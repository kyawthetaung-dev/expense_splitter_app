import 'package:expense_splitter_app/models/split_type.dart';
import 'package:expense_splitter_app/services/expense_share_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/kta_uks_ast_ksdl_scenario.dart';

void main() {
  group('calculateExpenseShares', () {
    test('Swimming Pool: 30,000 split equally among 3 (KSDL excluded)', () {
      final result = calculateExpenseShares(
        totalAmount: 30000,
        splitType: SplitType.equal,
        participantIds: KtaUksAstKsdlScenario.swimmingPoolParticipantIds,
      );
      final byId = {for (final r in result) r.participantId: r.shareAmount};
      expect(byId, {
        KtaUksAstKsdlScenario.kta: 10000,
        KtaUksAstKsdlScenario.uks: 10000,
        KtaUksAstKsdlScenario.ast: 10000,
      });
    });

    test('BBQ: 8,500 split equally among all 4', () {
      final result = calculateExpenseShares(
        totalAmount: 8500,
        splitType: SplitType.equal,
        participantIds: KtaUksAstKsdlScenario.allParticipantIds,
      );
      final byId = {for (final r in result) r.participantId: r.shareAmount};
      expect(byId.values, everyElement(2125));
    });

    test('G&G: 19,600 split equally among all 4', () {
      final result = calculateExpenseShares(
        totalAmount: 19600,
        splitType: SplitType.equal,
        participantIds: KtaUksAstKsdlScenario.allParticipantIds,
      );
      final byId = {for (final r in result) r.participantId: r.shareAmount};
      expect(byId.values, everyElement(4900));
    });

    test('non-divisible amount distributes remainder and sums exactly', () {
      final result = calculateExpenseShares(
        totalAmount: 100000,
        splitType: SplitType.equal,
        participantIds: ['a', 'b', 'c'],
      );
      final byId = {for (final r in result) r.participantId: r.shareAmount};
      expect(byId.values.fold<int>(0, (a, b) => a + b), 100000);
      expect(byId.values.toSet(), {33333, 33334});
      expect(byId.values.where((v) => v == 33334).length, 1);
    });

    test('remainder distribution is independent of input order (idempotent re-save)', () {
      final a = calculateExpenseShares(
        totalAmount: 100,
        splitType: SplitType.equal,
        participantIds: ['z', 'a', 'm'],
      );
      final b = calculateExpenseShares(
        totalAmount: 100,
        splitType: SplitType.equal,
        participantIds: ['m', 'z', 'a'],
      );
      final byIdA = {for (final r in a) r.participantId: r.shareAmount};
      final byIdB = {for (final r in b) r.participantId: r.shareAmount};
      expect(byIdA, byIdB);
    });

    test('single participant gets the full amount', () {
      final result = calculateExpenseShares(
        totalAmount: 12345,
        splitType: SplitType.equal,
        participantIds: ['solo'],
      );
      expect(result, hasLength(1));
      expect(result.single.participantId, 'solo');
      expect(result.single.shareAmount, 12345);
    });

    test('zero amount produces zero shares for everyone, no crash', () {
      final result = calculateExpenseShares(
        totalAmount: 0,
        splitType: SplitType.equal,
        participantIds: ['a', 'b'],
      );
      expect(result.every((r) => r.shareAmount == 0), isTrue);
    });

    test('negative amount is rejected', () {
      expect(
        () => calculateExpenseShares(
          totalAmount: -100,
          splitType: SplitType.equal,
          participantIds: ['a'],
        ),
        throwsArgumentError,
      );
    });

    test('empty participant list is rejected', () {
      expect(
        () => calculateExpenseShares(
          totalAmount: 100,
          splitType: SplitType.equal,
          participantIds: [],
        ),
        throwsArgumentError,
      );
    });

    test('duplicate participant ids are rejected', () {
      expect(
        () => calculateExpenseShares(
          totalAmount: 100,
          splitType: SplitType.equal,
          participantIds: ['a', 'a'],
        ),
        throwsArgumentError,
      );
    });

    test('custom split uses the exact provided amounts', () {
      final result = calculateExpenseShares(
        totalAmount: 100,
        splitType: SplitType.custom,
        participantIds: ['a', 'b'],
        customAmounts: {'a': 70, 'b': 30},
      );
      final byId = {for (final r in result) r.participantId: r.shareAmount};
      expect(byId, {'a': 70, 'b': 30});
    });

    test('custom split rejects amounts that do not sum to total', () {
      expect(
        () => calculateExpenseShares(
          totalAmount: 100,
          splitType: SplitType.custom,
          participantIds: ['a', 'b'],
          customAmounts: {'a': 70, 'b': 20},
        ),
        throwsArgumentError,
      );
    });

    test('percentage split distributes proportionally and sums exactly', () {
      final result = calculateExpenseShares(
        totalAmount: 100,
        splitType: SplitType.percentage,
        participantIds: ['a', 'b', 'c'],
        percentages: {'a': 33.33, 'b': 33.33, 'c': 33.34},
      );
      final total = result.fold<int>(0, (sum, r) => sum + r.shareAmount);
      expect(total, 100);
    });

    test('custom split rejects a negative amount even when the sum matches', () {
      expect(
        () => calculateExpenseShares(
          totalAmount: 1000,
          splitType: SplitType.custom,
          participantIds: ['a', 'b'],
          customAmounts: {'a': 1500, 'b': -500},
        ),
        throwsArgumentError,
      );
    });
  });

  group('derivePercentagesFromShares', () {
    test('thirds sum to exactly 100, with drift on the lowest id when tied', () {
      expect(
        derivePercentagesFromShares({'a': 1000, 'b': 1000, 'c': 1000}),
        {'a': 33.34, 'b': 33.33, 'c': 33.33},
      );
    });

    test('drift goes to the largest share', () {
      expect(
        derivePercentagesFromShares({'a': 1, 'b': 1, 'c': 1, 'd': 3}),
        {'a': 16.67, 'b': 16.67, 'c': 16.67, 'd': 49.99},
      );
    });

    test('whole percentages are unchanged', () {
      expect(derivePercentagesFromShares({'a': 750, 'b': 250}), {'a': 75.0, 'b': 25.0});
    });

    test('shares summing to zero derive nothing', () {
      expect(derivePercentagesFromShares({'a': 0, 'b': 0}), isEmpty);
      expect(derivePercentagesFromShares({}), isEmpty);
    });

    test('derived percentages re-save to the same shares (old expenses stay editable)', () {
      const shares = {'a': 1000, 'b': 1000, 'c': 1000};
      final result = calculateExpenseShares(
        totalAmount: 3000,
        splitType: SplitType.percentage,
        participantIds: shares.keys.toList(),
        percentages: derivePercentagesFromShares(shares),
      );
      expect({for (final r in result) r.participantId: r.shareAmount}, shares);
    });
  });
}
