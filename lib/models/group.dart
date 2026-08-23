class Group {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Group({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  Group copyWith({String? name, DateTime? updatedAt}) {
    return Group(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
