import 'package:hive_ce/hive.dart';

import '../../models/group.dart';
import 'hive_type_ids.dart';

class GroupAdapter extends TypeAdapter<Group> {
  @override
  final int typeId = HiveTypeIds.group;

  @override
  Group read(BinaryReader reader) {
    final fields = reader.readMap().cast<int, dynamic>();
    return Group(
      id: fields[0] as String,
      name: fields[1] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[2] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
    );
  }

  @override
  void write(BinaryWriter writer, Group obj) {
    writer.writeMap({
      0: obj.id,
      1: obj.name,
      2: obj.createdAt.millisecondsSinceEpoch,
      3: obj.updatedAt.millisecondsSinceEpoch,
    });
  }
}
