class Participant {
  final String id;
  final String groupId;
  final String name;

  const Participant({
    required this.id,
    required this.groupId,
    required this.name,
  });

  Participant copyWith({String? name}) {
    return Participant(id: id, groupId: groupId, name: name ?? this.name);
  }
}
