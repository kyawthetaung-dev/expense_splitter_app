import 'dart:io';

import 'package:expense_splitter_app/data/hive/hive_boxes.dart';
import 'package:expense_splitter_app/models/split_type.dart';
import 'package:expense_splitter_app/providers/expense_providers.dart';
import 'package:expense_splitter_app/providers/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

void main() {
  late Directory tempDir;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_expense_controller_test');
    await HiveBoxes.initForTest(tempDir.path);
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> save({
    String? expenseId,
    required SplitType splitType,
    Map<String, double>? percentages,
    Map<String, int>? customAmounts,
    Map<String, int> payerAmounts = const {'a': 3000},
  }) {
    return container.read(expenseControllerProvider).saveExpense(
      groupId: 'g1',
      expenseId: expenseId,
      title: 'Hotel',
      totalAmount: 3000,
      splitType: splitType,
      payerAmounts: payerAmounts,
      participantIds: const ['a', 'b', 'c'],
      percentages: percentages,
      customAmounts: customAmounts,
    );
  }

  test('a percentage expense re-saves unchanged from its stored percentages', () async {
    const entered = {'a': 33.33, 'b': 33.33, 'c': 33.34};
    await save(splitType: SplitType.percentage, percentages: entered);

    final repo = container.read(expenseRepositoryProvider);
    final saved = repo.getAll().single;
    expect(saved.percentages, entered);

    await save(
      expenseId: saved.id,
      splitType: SplitType.percentage,
      percentages: saved.percentages,
    );

    expect(repo.getAll().single.percentages, entered);
    expect(repo.getShares(saved.id).map((s) => s.shareAmount), everyElement(1000));
  });

  test('switching away from percentage clears the stored percentages', () async {
    await save(
      splitType: SplitType.percentage,
      percentages: const {'a': 50, 'b': 25, 'c': 25},
    );
    final repo = container.read(expenseRepositoryProvider);
    final id = repo.getAll().single.id;

    await save(expenseId: id, splitType: SplitType.equal);

    expect(repo.getById(id)!.percentages, isNull);
  });

  test('negative splits are rejected and nothing is saved', () async {
    await expectLater(
      save(
        splitType: SplitType.percentage,
        percentages: const {'a': 150, 'b': -25, 'c': -25},
      ),
      throwsArgumentError,
    );
    await expectLater(
      save(
        splitType: SplitType.custom,
        customAmounts: const {'a': 4000, 'b': -500, 'c': -500},
      ),
      throwsArgumentError,
    );

    expect(container.read(expenseRepositoryProvider).getAll(), isEmpty);
  });
}
