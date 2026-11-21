import 'package:hive_ce/hive.dart';

import '../../models/expense.dart';
import '../../models/split_type.dart';
import 'hive_type_ids.dart';

class ExpenseAdapter extends TypeAdapter<Expense> {
  @override
  final int typeId = HiveTypeIds.expense;

  @override
  Expense read(BinaryReader reader) {
    final fields = reader.readMap().cast<int, dynamic>();
    return Expense(
      id: fields[0] as String,
      groupId: fields[1] as String,
      title: fields[2] as String,
      totalAmount: fields[3] as int,
      splitType: SplitType.values[fields[4] as int],
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[5] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(fields[6] as int),
      percentages: (fields[7] as Map?)?.map(
        (key, value) => MapEntry(key as String, (value as num).toDouble()),
      ),
    );
  }

  @override
  void write(BinaryWriter writer, Expense obj) {
    writer.writeMap({
      0: obj.id,
      1: obj.groupId,
      2: obj.title,
      3: obj.totalAmount,
      4: obj.splitType.index,
      5: obj.createdAt.millisecondsSinceEpoch,
      6: obj.updatedAt.millisecondsSinceEpoch,
      7: obj.percentages,
    });
  }
}
