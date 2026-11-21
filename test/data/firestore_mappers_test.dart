import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:expense_splitter_app/data/store/firestore_mappers.dart';
import 'package:expense_splitter_app/data/store/invoice_store.dart';
import 'package:expense_splitter_app/models/split_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Documents here are shaped as firestore.rules expects them.
void main() {
  // Local, as Timestamp.toDate() returns local time.
  final jan = DateTime(2026, 1, 1);
  final feb = DateTime(2026, 2, 1);

  Doc invoice(
    String id, {
    DateTime? updatedAt,
    Map<String, Object?>? participants,
    Map<String, Object?>? summary,
  }) => (
    id,
    {
      'name': 'Trip $id',
      'status': 'open',
      'assignedUids': ['alice'],
      'participants':
          participants ??
          {
            'alice': {'name': 'Alice', 'kind': 'user', 'uid': 'alice'},
            'g-bob': {'name': 'Bob', 'kind': 'guest', 'uid': null},
          },
      'createdBy': 'alice',
      'summary': ?summary,
      'createdAt': Timestamp.fromDate(jan),
      'updatedAt': Timestamp.fromDate(updatedAt ?? jan),
    },
  );

  Doc voucher(
    String id, {
    Object? percentages,
    Map<String, int> payers = const {'alice': 3000},
    Map<String, int> shares = const {'alice': 1500, 'g-bob': 1500},
  }) => (
    id,
    {
      'title': 'Dinner',
      'totalAmount': 3000,
      'splitType': percentages == null ? 'equal' : 'percentage',
      'percentages': percentages,
      'payers': payers,
      'shares': shares,
      'integrity': 'ok',
      'revision': 2,
      'createdAt': Timestamp.fromDate(jan),
      'updatedAt': Timestamp.fromDate(feb),
    },
  );

  group('reading', () {
    test('the group list uses the stored summary, newest first', () {
      final items = groupListFromInvoices([
        invoice('old', summary: {'voucherCount': 4, 'isFullySettled': false}),
        invoice('new', updatedAt: feb),
      ]);

      expect([for (final i in items) i.group.id], ['new', 'old']);
      final old = items.last;
      expect(old.group.name, 'Trip old');
      expect(old.participantCount, 2);
      expect(old.expenseCount, 4);
      expect(old.isFullySettled, isFalse);
      // No summary yet: nothing recorded, so nothing owed.
      expect(items.first.expenseCount, 0);
      expect(items.first.isFullySettled, isTrue);
    });

    test('a voucher becomes an expense in its invoice, with its revision', () {
      final expense = expenseFromVoucher('i1', voucher('v1'));

      expect(expense.groupId, 'i1');
      expect(expense.totalAmount, 3000);
      expect(expense.splitType, SplitType.equal);
      expect(expense.revision, 2);
      expect(expense.createdAt, jan);
      expect(expense.updatedAt, feb);
      expect(expense.percentages, isNull);
    });

    test('whole-number percentages come back as doubles', () {
      final expense = expenseFromVoucher(
        'i1',
        voucher('v1', percentages: {'alice': 50, 'g-bob': 49.5}),
      );
      expect(expense.percentages, {'alice': 50.0, 'g-bob': 49.5});
    });

    test('a missing server timestamp does not crash', () {
      final (id, data) = voucher('v1');
      final expense = expenseFromVoucher('i1', (id, {...data, 'updatedAt': null}));
      expect(expense.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('an invoice with its vouchers, payers and shares', () {
      final snapshot = invoiceSnapshotFrom(
        invoice: invoice('i1'),
        vouchers: [voucher('v1')],
      );

      expect({for (final p in snapshot.participants) p.id: p.name}, {
        'alice': 'Alice',
        'g-bob': 'Bob',
      });
      expect(snapshot.expenses.single.id, 'v1');
      expect(snapshot.payers.single.paidAmount, 3000);
      expect(snapshot.payers.single.expenseId, 'v1');
      expect({for (final s in snapshot.shares) s.participantId: s.shareAmount}, {
        'alice': 1500,
        'g-bob': 1500,
      });
    });

    test('the overall view counts only vouchers of visible invoices', () {
      final overall = overallSnapshotFrom(
        invoices: [invoice('i1')],
        vouchersByInvoice: {
          'i1': [voucher('v1')],
          'gone': [voucher('v2', payers: {'alice': 999})],
        },
      );

      expect([for (final e in overall.expenses) e.id], ['v1']);
      expect(overall.payers.single.paidAmount, 3000);
    });

    test('someone on several invoices appears once overall', () {
      final overall = overallSnapshotFrom(
        invoices: [invoice('i1'), invoice('i2')],
        vouchersByInvoice: const {},
      );
      expect(overall.participants, hasLength(2));
      expect(overall.groups, hasLength(2));
    });

    test('a linked contact is known by their account id', () {
      final guest = contactFrom(('c1', {'name': 'Bob', 'linkedUid': null}));
      final linked = contactFrom(('c2', {'name': 'Cat', 'linkedUid': 'cat'}));

      expect(guest.toParticipant().id, 'c1');
      expect(linked.toParticipant().id, 'cat');
      expect(linked.toParticipant().name, 'Cat');
    });
  });

  group('writing', () {
    ExpenseInput input(
      SplitType splitType, {
      List<String> participantIds = const ['alice', 'g-bob'],
      Map<String, int> payers = const {'alice': 3000, 'g-bob': 0},
    }) => ExpenseInput(
      groupId: 'i1',
      expenseId: 'v1',
      isNew: true,
      title: '  Hotel ',
      totalAmount: 3000,
      splitType: splitType,
      payerAmounts: payers,
      participantIds: participantIds,
      customAmounts: const {'alice': 1000, 'g-bob': 2000},
      percentages: const {'alice': 33.33, 'g-bob': 66.67},
    );

    DocData fields(ExpenseInput input) => voucherFields(
      input,
      uid: 'alice',
      revision: 1,
      createdBy: 'alice',
      createdAt: 'created',
      updatedAt: 'updated',
    );

    test('a voucher stores its shares, worked out by the shared calculator', () {
      final data = fields(input(SplitType.percentage));
      expect(data['title'], 'Hotel');
      expect(data['shares'], {'alice': 1000, 'g-bob': 2000});
      expect(data['percentages'], {'alice': 33.33, 'g-bob': 66.67});
      expect(data['integrity'], 'ok');
      expect(data['updatedBy'], 'alice');
    });

    test('payers who paid nothing are left out, as the rules sum what is there', () {
      expect(fields(input(SplitType.equal))['payers'], {'alice': 3000});
    });

    test('only percentage splits keep their percentages', () {
      expect(fields(input(SplitType.custom))['percentages'], isNull);
      expect(fields(input(SplitType.custom))['shares'], {'alice': 1000, 'g-bob': 2000});
    });

    test('more people than the rules can check is refused before sending', () {
      final people = [for (var i = 0; i <= maxPeoplePerVoucher; i++) 'p$i'];
      expect(
        () => fields(input(SplitType.equal, participantIds: people)),
        throwsA(isA<StoreException>()),
      );
    });

    test('guests are stored with their name, linked people by account', () {
      final contacts = {
        for (final c in [
          const ContactEntry(id: 'c1', name: 'Bob'),
          const ContactEntry(id: 'c2', name: 'Cat', linkedUid: 'cat'),
        ])
          c.participantId: c,
      };

      final participants = participantsFor(['c1', 'cat'], contacts);
      expect(participants, {
        'c1': {'name': 'Bob', 'kind': 'guest', 'uid': null},
        'cat': {'name': 'Cat', 'kind': 'user', 'uid': 'cat'},
      });
      expect(assignedUidsFor('alice', participants)..sort(), ['alice', 'cat']);
    });

    test('picking someone no longer in the list is refused before sending', () {
      expect(
        () => participantsFor(['gone'], const {}),
        throwsA(isA<StoreException>()),
      );
    });

    test('the summary is recomputed from every voucher', () {
      final summary = summaryFor(invoice('i1').$2, [voucher('v1'), voucher('v2')]);
      expect(summary, {
        'voucherCount': 2,
        'totalAmount': 6000,
        'totalPaid': 6000,
        'totalOutstanding': 3000,
        'isFullySettled': false,
      });
    });

    test('everyone named on a voucher counts as having history', () {
      expect(
        peopleWithHistory([
          voucher('v1', payers: {'cat': 3000}, shares: {'alice': 3000}),
        ]),
        {'cat', 'alice'},
      );
    });
  });

  group('errors', () {
    test('network failures ask to check the connection', () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        expect(storeErrorFor(code).message, contains('Check your connection'));
      }
    });

    test('a refusal by the rules names the usual reasons', () {
      expect(storeErrorFor('permission-denied').message, contains('completed'));
    });

    test('unexpected failures get a generic message', () {
      expect(storeErrorFor('internal').message, "That didn't work. Please try again.");
    });

    test('an ended session asks to sign in again', () {
      expect(storeErrorFor('unauthenticated').message, contains('Sign in'));
    });
  });
}
