import 'package:hive_ce/hive.dart';

import '../../models/settlement.dart';
import 'hive_type_ids.dart';

class SettlementStatusAdapter extends TypeAdapter<SettlementStatus> {
  @override
  final int typeId = HiveTypeIds.settlementStatus;

  @override
  SettlementStatus read(BinaryReader reader) {
    final index = reader.readByte();
    return SettlementStatus.values[index];
  }

  @override
  void write(BinaryWriter writer, SettlementStatus obj) {
    writer.writeByte(obj.index);
  }
}
