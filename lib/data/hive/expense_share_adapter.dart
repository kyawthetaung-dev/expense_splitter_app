import 'package:hive_ce/hive.dart';

import '../../models/expense_share.dart';
import 'hive_type_ids.dart';

class ExpenseShareAdapter extends TypeAdapter<ExpenseShare> {
  @override
  final int typeId = HiveTypeIds.expenseShare;

  @override
  ExpenseShare read(BinaryReader reader) {
    final fields = reader.readMap().cast<int, dynamic>();
    return ExpenseShare(
      id: fields[0] as String,
      expenseId: fields[1] as String,
      participantId: fields[2] as String,
      shareAmount: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseShare obj) {
    writer.writeMap({
      0: obj.id,
      1: obj.expenseId,
      2: obj.participantId,
      3: obj.shareAmount,
    });
  }
}
