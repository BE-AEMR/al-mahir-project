class TransactionSubcategory {
  final String id;
  final String categoryId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const TransactionSubcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory TransactionSubcategory.fromJson(Map<String, dynamic> json) {
    return TransactionSubcategory(
      id: json['id'],
      categoryId: json['category_id'],
      name: json['name'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
  
  // Créer une copie de cette instance avec des valeurs modifiées
  TransactionSubcategory copyWith({
    String? id,
    String? categoryId,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionSubcategory(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
