import 'dart:convert';
import 'dart:io';

import 'package:expense_splitter_app/models/expense_payer.dart';
import 'package:expense_splitter_app/models/expense_share.dart';
import 'package:expense_splitter_app/models/participant.dart';
import 'package:expense_splitter_app/models/person_balance.dart';
import 'package:expense_splitter_app/models/split_type.dart';
import 'package:expense_splitter_app/services/balance_calculator.dart';
import 'package:expense_splitter_app/services/expense_share_calculator.dart';
import 'package:expense_splitter_app/services/settlement_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the hand-verified golden cases against the calculators.
void main() {
  final golden =
      jsonDecode(File('test/fixtures/golden/calculators.json').readAsStringSync())
          as Map<String, dynamic>;

  List<ExpenseShareResult> sharesFor(Map<String, dynamic> c) {
    return calculateExpenseShares(
      totalAmount: c['totalAmount'] as int,
      splitType: SplitType.values.byName(c['splitType'] as String),
      participantIds: (c['participantIds'] as List).cast<String>(),
      customAmounts: (c['customAmounts'] as Map<String, dynamic>?)?.map(
        (id, amount) => MapEntry(id, amount as int),
      ),
      percentages: (c['percentages'] as Map<String, dynamic>?)?.map(
        (id, pct) => MapEntry(id, (pct as num).toDouble()),
      ),
    );
  }

  group('shares', () {
    for (final c in (golden['shares'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'], () {
        final result = sharesFor(c);
        expect(
          {for (final r in result) r.participantId: r.shareAmount},
          c['expected'],
        );
      });
    }
  });

  group('rejected shares', () {
    for (final c in (golden['sharesRejected'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'], () {
        expect(() => sharesFor(c), throwsArgumentError);
      });
    }
  });

  group('balances', () {
    for (final c in (golden['balances'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'], () {
        final payers = (c['payers'] as List).cast<Map<String, dynamic>>();
        final shares = (c['shares'] as List).cast<Map<String, dynamic>>();
        final result = calculatePersonBalances(
          participants: [
            for (final id in (c['participants'] as List).cast<String>())
              Participant(id: id, name: id),
          ],
          allPayers: [
            for (final (i, p) in payers.indexed)
              ExpensePayer(
                id: 'p$i',
                expenseId: 'e',
                participantId: p['participantId'] as String,
                paidAmount: p['amount'] as int,
              ),
          ],
          allShares: [
            for (final (i, s) in shares.indexed)
              ExpenseShare(
                id: 's$i',
                expenseId: 'e',
                participantId: s['participantId'] as String,
                shareAmount: s['amount'] as int,
              ),
          ],
        );
        expect({
          for (final b in result)
            b.participantId: {
              'totalShare': b.totalShare,
              'totalPaid': b.totalPaid,
              'balance': b.balance,
              'status': b.status.name,
            },
        }, c['expected']);
      });
    }
  });

  group('settlements', () {
    for (final c in (golden['settlements'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'], () {
        final balances = (c['balances'] as Map<String, dynamic>).cast<String, int>();
        final result = calculateSettlements(
          balances: [
            for (final MapEntry(key: id, value: balance) in balances.entries)
              PersonBalance(
                participantId: id,
                totalShare: 0,
                totalPaid: 0,
                balance: balance,
                status: balance > 0
                    ? BalanceStatus.receive
                    : balance < 0
                    ? BalanceStatus.pay
                    : BalanceStatus.settled,
              ),
          ],
        );
        expect(
          [
            for (final t in result)
              {
                'from': t.fromParticipantId,
                'to': t.toParticipantId,
                'amount': t.amount,
              },
          ],
          c['expected'],
        );
      });
    }
  });
}
