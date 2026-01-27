class Friend {
  final String id;
  final String name;
  final String? avatarUrl;
  bool isSelected;

  Friend({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isSelected = false,
  });
}