import 'package:hive_ce/hive.dart';

import '../../models/settlement.dart';
import 'hive_type_ids.dart';

class SettlementAdapter extends TypeAdapter<Settlement> {
  @override
  final int typeId = HiveTypeIds.settlement;

  @override
  Settlement read(BinaryReader reader) {
    final fields = reader.readMap().cast<int, dynamic>();
    return Settlement(
      id: fields[0] as String,
      groupId: fields[1] as String,
      fromParticipantId: fields[2] as String,
      toParticipantId: fields[3] as String,
      amount: fields[4] as int,
      status: SettlementStatus.values[fields[5] as int],
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[6] as int),
    );
  }

  @override
  void write(BinaryWriter writer, Settlement obj) {
    writer.writeMap({
      0: obj.id,
      1: obj.groupId,
      2: obj.fromParticipantId,
      3: obj.toParticipantId,
      4: obj.amount,
      5: obj.status.index,
      6: obj.createdAt.millisecondsSinceEpoch,
    });
  }
}
