import 'dart:async';
import 'dart:io';

import 'package:expense_splitter_app/data/hive/hive_boxes.dart';
import 'package:expense_splitter_app/data/repositories/expense_repository.dart';
import 'package:expense_splitter_app/data/repositories/group_repository.dart';
import 'package:expense_splitter_app/data/repositories/participant_repository.dart';
import 'package:expense_splitter_app/data/store/hive_invoice_store.dart';
import 'package:expense_splitter_app/data/store/invoice_store.dart';
import 'package:expense_splitter_app/models/split_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

void main() {
  late Directory tempDir;
  late HiveInvoiceStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_invoice_store_test');
    await HiveBoxes.initForTest(tempDir.path);
    final expenses = ExpenseRepository();
    store = HiveInvoiceStore(
      expenses: expenses,
      groups: GroupRepository(expenseRepository: expenses),
      participants: ParticipantRepository(),
    );
  });

  tearDown(() async {
    store.dispose();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Collects everything [stream] emits until the test ends.
  List<T> record<T>(Stream<T> stream) {
    final events = <T>[];
    final subscription = stream.listen(events.add);
    addTearDown(subscription.cancel);
    return events;
  }

  ExpenseInput dinner(String groupId, List<String> ids, {String id = 'e1'}) =>
      ExpenseInput(
        groupId: groupId,
        expenseId: id,
        isNew: true,
        title: ' Dinner ',
        totalAmount: 3000,
        splitType: SplitType.equal,
        payerAmounts: {ids.first: 3000},
        participantIds: ids,
      );

  Future<(String, String, String)> tripWithTwo() async {
    final alex = await store.createContact('Alex');
    final sam = await store.createContact('Sam');
    await store.createGroup(
      groupId: 'g1',
      name: 'Trip',
      participantIds: [alex.id, sam.id],
    );
    return ('g1', alex.id, sam.id);
  }

  test('a group emits straight away, then again with each saved expense', () async {
    final (groupId, alex, sam) = await tripWithTwo();
    final events = record(store.watchInvoice(groupId));
    await pumpEventQueue();
    expect(events.single!.expenses, isEmpty);

    await store.saveExpense(dinner(groupId, [alex, sam]));
    await pumpEventQueue();

    final latest = events.last!;
    expect(latest.expenses.single.title, 'Dinner');
    expect(
      {for (final s in latest.shares) s.participantId: s.shareAmount},
      {alex: 1500, sam: 1500},
    );
    expect(latest.payers.single.paidAmount, 3000);
  });

  test('editing keeps when the expense was created', () async {
    final (groupId, alex, sam) = await tripWithTwo();
    await store.saveExpense(dinner(groupId, [alex, sam]));
    final created = ExpenseRepository().getById('e1')!.createdAt;

    await store.saveExpense(
      ExpenseInput(
        groupId: groupId,
        expenseId: 'e1',
        isNew: false,
        title: 'Dinner',
        totalAmount: 1000,
        splitType: SplitType.equal,
        payerAmounts: {sam: 1000},
        participantIds: [sam],
      ),
    );

    final saved = ExpenseRepository().getById('e1')!;
    expect(saved.createdAt, created);
    expect(saved.totalAmount, 1000);
    expect(ExpenseRepository().getShares('e1').single.participantId, sam);
  });

  test('a bad split is refused through the returned future, saving nothing', () async {
    final (groupId, alex, sam) = await tripWithTwo();
    await expectLater(
      store.saveExpense(
        ExpenseInput(
          groupId: groupId,
          expenseId: 'e1',
          isNew: true,
          title: 'Hotel',
          totalAmount: 3000,
          splitType: SplitType.custom,
          payerAmounts: {alex: 3000},
          participantIds: [alex, sam],
          customAmounts: {alex: 1000, sam: 1000},
        ),
      ),
      throwsArgumentError,
    );
    expect(ExpenseRepository().getAll(), isEmpty);
  });

  test('the group list shows counts and whether the group is settled', () async {
    final (groupId, alex, sam) = await tripWithTwo();
    final events = record(store.watchGroups());
    await pumpEventQueue();
    expect(events.last.single.isFullySettled, isTrue);

    await store.saveExpense(dinner(groupId, [alex, sam]));
    await pumpEventQueue();

    final item = events.last.single;
    expect(item.group.name, 'Trip');
    expect(item.participantCount, 2);
    expect(item.expenseCount, 1);
    expect(item.isFullySettled, isFalse);
  });

  test('the group list puts the most recently changed group first', () async {
    await store.createGroup(groupId: 'old', name: 'Old', participantIds: []);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await store.createGroup(groupId: 'new', name: 'New', participantIds: []);

    final events = record(store.watchGroups());
    await pumpEventQueue();

    expect([for (final item in events.last) item.group.id], ['new', 'old']);
  });

  test('a deleted group emits null, so its screens can close', () async {
    final (groupId, _, _) = await tripWithTwo();
    final events = record(store.watchInvoice(groupId));
    await pumpEventQueue();

    await store.deleteGroup(groupId);
    await pumpEventQueue();

    expect(events.last, isNull);
  });

  test('membership changes apply on top of the current members', () async {
    final (groupId, alex, sam) = await tripWithTwo();
    final kim = await store.createContact('Kim');

    await store.updateGroupParticipants(groupId, add: {kim.id}, remove: {sam});

    final members = GroupRepository(
      expenseRepository: ExpenseRepository(),
    ).getParticipantIds(groupId);
    expect(members.toSet(), {alex, kim.id});
  });

  test('removing someone with history is refused and changes nothing', () async {
    final (groupId, alex, sam) = await tripWithTwo();
    final kim = await store.createContact('Kim');
    await store.saveExpense(dinner(groupId, [alex]));

    await expectLater(
      store.updateGroupParticipants(groupId, add: {kim.id}, remove: {alex}),
      throwsA(isA<GroupParticipantReferencedException>()),
    );

    final members = GroupRepository(
      expenseRepository: ExpenseRepository(),
    ).getParticipantIds(groupId);
    expect(members.toSet(), {alex, sam});
  });

  test('the overall summary covers everyone, even those in no group', () async {
    final (groupId, alex, sam) = await tripWithTwo();
    final loner = await store.createContact('Loner');
    await store.saveExpense(dinner(groupId, [alex, sam]));

    final overall = await store.watchOverall().first;

    expect({for (final p in overall.participants) p.id}, {alex, sam, loner.id});
    expect(overall.groups.single.id, groupId);
    expect(overall.payers, hasLength(1));
    expect(overall.shares, hasLength(2));
  });

  test('contacts update as they change', () async {
    final events = record(store.watchContacts());
    await pumpEventQueue();
    expect(events.single, isEmpty);

    final alex = await store.createContact('  Alex ');
    await store.renameContact(alex, 'Alexander');
    await pumpEventQueue();

    expect(events.last.single.name, 'Alexander');

    await store.deleteContact(alex.id);
    await pumpEventQueue();
    expect(events.last, isEmpty);
  });

  test('deleting a contact with history needs force', () async {
    final (groupId, alex, sam) = await tripWithTwo();
    await store.saveExpense(dinner(groupId, [alex, sam]));

    await expectLater(
      store.deleteContact(alex),
      throwsA(isA<ParticipantReferencedException>()),
    );
    await store.deleteContact(alex, force: true);

    expect(ParticipantRepository().getById(alex), isNull);
  });
}
