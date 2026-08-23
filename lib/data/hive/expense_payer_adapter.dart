import 'package:hive_ce/hive.dart';

import '../../models/expense_payer.dart';
import 'hive_type_ids.dart';

class ExpensePayerAdapter extends TypeAdapter<ExpensePayer> {
  @override
  final int typeId = HiveTypeIds.expensePayer;

  @override
  ExpensePayer read(BinaryReader reader) {
    final fields = reader.readMap().cast<int, dynamic>();
    return ExpensePayer(
      id: fields[0] as String,
      expenseId: fields[1] as String,
      participantId: fields[2] as String,
      paidAmount: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ExpensePayer obj) {
    writer.writeMap({
      0: obj.id,
      1: obj.expenseId,
      2: obj.participantId,
      3: obj.paidAmount,
    });
  }
}
