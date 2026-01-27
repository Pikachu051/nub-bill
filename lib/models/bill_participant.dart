class BillParticipant {
  final String id;
  final String name;
  final String? avatarUrl;
  final double amount;
  final bool isPaid;

  const BillParticipant({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.amount,
    this.isPaid = false,
  });
}