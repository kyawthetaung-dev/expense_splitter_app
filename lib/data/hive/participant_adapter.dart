import 'package:hive_ce/hive.dart';

import '../../models/participant.dart';
import 'hive_type_ids.dart';

class ParticipantAdapter extends TypeAdapter<Participant> {
  @override
  final int typeId = HiveTypeIds.participant;

  @override
  Participant read(BinaryReader reader) {
    final fields = reader.readMap().cast<int, dynamic>();
    return Participant(id: fields[0] as String, name: fields[1] as String);
  }

  @override
  void write(BinaryWriter writer, Participant obj) {
    writer.writeMap({0: obj.id, 1: obj.name});
  }
}
