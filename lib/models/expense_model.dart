class Expense {
  final String id;
  final String title;
  final double amount;
  final String payerId;
  final String? groupId;
  final DateTime date;
  final String? createdBy;

  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.payerId,
    this.groupId,
    required this.date,
    this.createdBy,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      payerId: json['payer_id'] as String,
      groupId: json['group_id'] as String?,
      date: DateTime.parse(json['date'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'payer_id': payerId,
      'group_id': groupId,
      'date': date.toIso8601String(),
      'created_by': createdBy,
    };
  }
}
