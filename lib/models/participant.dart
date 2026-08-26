class Participant {
  final String id;
  final String name;

  const Participant({required this.id, required this.name});

  Participant copyWith({String? name}) {
    return Participant(id: id, name: name ?? this.name);
  }
}
