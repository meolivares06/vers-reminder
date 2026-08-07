class Category {
  final int? id;
  final String name;
  final bool isSeed;

  Category({
    this.id,
    required this.name,
    this.isSeed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'isSeed': isSeed ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      isSeed: (map['isSeed'] as int) == 1,
    );
  }

  Category copyWith({
    int? id,
    String? name,
    bool? isSeed,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      isSeed: isSeed ?? this.isSeed,
    );
  }
}
