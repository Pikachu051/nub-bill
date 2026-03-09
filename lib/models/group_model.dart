class Group {
  final String id;
  final String name;
  final String? imageUrl;
  final DateTime createdAt;
  final String? createdBy;

  const Group({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.createdAt,
    this.createdBy,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }
}
