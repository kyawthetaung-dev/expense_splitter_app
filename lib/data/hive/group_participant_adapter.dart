import 'package:hive_ce/hive.dart';

import '../../models/group_participant.dart';
import 'hive_type_ids.dart';

class GroupParticipantAdapter extends TypeAdapter<GroupParticipant> {
  @override
  final int typeId = HiveTypeIds.groupParticipant;

  @override
  GroupParticipant read(BinaryReader reader) {
    final fields = reader.readMap().cast<int, dynamic>();
    return GroupParticipant(
      id: fields[0] as String,
      groupId: fields[1] as String,
      participantId: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, GroupParticipant obj) {
    writer.writeMap({0: obj.id, 1: obj.groupId, 2: obj.participantId});
  }
}
