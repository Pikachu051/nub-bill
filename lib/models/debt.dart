class Debt {
  final String id;
  final String personName;
  final String? avatarUrl;
  final double amount;
  final bool isOwedToYou; // true = they owe you, false = you owe them
  final String? statusLabel;

  const Debt({
    required this.id,
    required this.personName,
    this.avatarUrl,
    required this.amount,
    required this.isOwedToYou,
    this.statusLabel,
  });
}