import 'package:hive_ce/hive.dart';

import '../../models/split_type.dart';
import 'hive_type_ids.dart';

class SplitTypeAdapter extends TypeAdapter<SplitType> {
  @override
  final int typeId = HiveTypeIds.splitType;

  @override
  SplitType read(BinaryReader reader) {
    final index = reader.readByte();
    return SplitType.values[index];
  }

  @override
  void write(BinaryWriter writer, SplitType obj) {
    writer.writeByte(obj.index);
  }
}
