class FamilyMember {
  final String id;
  final String name;
  final String relation;
  FamilyMember({required this.id, required this.name, required this.relation});
}

class FamilyService {
  static final FamilyService _instance = FamilyService._internal();
  factory FamilyService() => _instance;
  FamilyService._internal();

  final List<FamilyMember> _members = [];

  List<FamilyMember> get members => List.unmodifiable(_members);

  void addMember(String name, String relation) {
    if (name.trim().isEmpty) return;
    _members.add(FamilyMember(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      relation: relation.trim().isEmpty ? 'Family' : relation.trim(),
    ));
  }

  void removeMember(String id) {
    _members.removeWhere((m) => m.id == id);
  }
}