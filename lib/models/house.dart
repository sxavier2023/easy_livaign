class House {
  final String id;
  final String name;
  final String ownerId;
  final List<String> members;

  House({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.members,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'ownerId': ownerId, 'members': members};
  }

  static House fromMap(Map<String, dynamic> map) {
    return House(
      id: map['id'],
      name: map['name'],
      ownerId: map['ownerId'],
      members: List<String>.from(map['members']),
    );
  }
}
