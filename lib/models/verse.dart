class Verse {
  final int? id;
  final String textEs;
  final String? textPt;
  final String citation;
  final DateTime createdAt;

  Verse({
    this.id,
    required this.textEs,
    this.textPt,
    required this.citation,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'textEs': textEs,
      'textPt': textPt,
      'citation': citation,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Verse.fromMap(Map<String, dynamic> map) {
    return Verse(
      id: map['id'] as int?,
      textEs: map['textEs'] as String,
      textPt: map['textPt'] as String?,
      citation: map['citation'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Verse copyWith({
    int? id,
    String? textEs,
    String? textPt,
    String? citation,
    DateTime? createdAt,
  }) {
    return Verse(
      id: id ?? this.id,
      textEs: textEs ?? this.textEs,
      textPt: textPt ?? this.textPt,
      citation: citation ?? this.citation,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
