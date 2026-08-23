import 'package:expense_splitter_app/models/person_balance.dart';
import 'package:expense_splitter_app/services/settlement_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

PersonBalance _balance(String id, int balance) {
  return PersonBalance(
    participantId: id,
    totalShare: 0,
    totalPaid: 0,
    balance: balance,
    status: balance > 0
        ? BalanceStatus.receive
        : balance < 0
            ? BalanceStatus.pay
            : BalanceStatus.settled,
  );
}

void main() {
  group('calculateSettlements', () {
    test('matches the spec example: single creditor, three debtors', () {
      final balances = [
        _balance('kta', -12025),
        _balance('uks', -17025),
        _balance('ast', -17025),
        _balance('ksdl', 46075),
      ];
      final result = calculateSettlements(balances: balances);

      expect(result, hasLength(3));
      expect(result.every((t) => t.toParticipantId == 'ksdl'), isTrue);
      final byFrom = {for (final t in result) t.fromParticipantId: t.amount};
      expect(byFrom, {'kta': 12025, 'uks': 17025, 'ast': 17025});
      expect(result.fold<int>(0, (sum, t) => sum + t.amount), 46075);
    });

    test('multiple debtors and multiple creditors simultaneously', () {
      final balances = [
        _balance('a', -50),
        _balance('b', -30),
        _balance('c', 40),
        _balance('d', 40),
      ];
      final result = calculateSettlements(balances: balances);

      int totalFrom(String id) =>
          result.where((t) => t.fromParticipantId == id).fold(0, (s, t) => s + t.amount);
      int totalTo(String id) =>
          result.where((t) => t.toParticipantId == id).fold(0, (s, t) => s + t.amount);

      expect(totalFrom('a'), 50);
      expect(totalFrom('b'), 30);
      expect(totalTo('c'), 40);
      expect(totalTo('d'), 40);
      expect(result.length, lessThanOrEqualTo(4));
    });

    test('fully settled group produces no settlements', () {
      final balances = [_balance('a', 0), _balance('b', 0)];
      expect(calculateSettlements(balances: balances), isEmpty);
    });

    test('does not crash when debts and credits are unbalanced (data inconsistency)', () {
      final balances = [_balance('a', -100)];
      final result = calculateSettlements(balances: balances);
      expect(result, isEmpty);
    });

    test('deterministic tie-break: equal-amount debtors ordered by ascending id', () {
      final balances = [
        _balance('zeta', -10),
        _balance('alpha', -10),
        _balance('creditor', 20),
      ];
      final result = calculateSettlements(balances: balances);
      expect(result.first.fromParticipantId, 'alpha');
      expect(result.last.fromParticipantId, 'zeta');
    });
  });
}
