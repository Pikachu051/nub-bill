import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';

/// Expense model matching the backend list response from GET /trips/:id/expenses
class Expense {
  final String id;
  final String tripId;
  final String payerId;
  final double amount;
  final String description;
  final String expenseDate;
  final String splitType; // equal, exact, percent
  final double serviceChargePercent;
  final double vatPercent;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final String? receiptUrl;

  // Nested payer info from join
  final ExpensePayer? payer;

  // Nested splits from join
  final List<ExpenseSplitSummary> splits;

  // Multi-payer entries (optional)
  final List<ExpensePayerInfo> payers;

  const Expense({
    required this.id,
    required this.tripId,
    required this.payerId,
    required this.amount,
    required this.description,
    required this.expenseDate,
    this.splitType = 'equal',
    this.serviceChargePercent = 0,
    this.vatPercent = 0,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.receiptUrl,
    this.payer,
    this.splits = const [],
    this.payers = const [],
  });

  /// Category icon based on description heuristics
  IconData get categoryIcon {
    final desc = description.toLowerCase();
    if (desc.contains('อาหาร') ||
        desc.contains('ข้าว') ||
        desc.contains('กิน') ||
        desc.contains('มื้อ') ||
        desc.contains('restaurant') ||
        desc.contains('แม็กโดนัล') ||
        desc.contains('7-eleven')) {
      return AppIcons.restaurant;
    }
    if (desc.contains('ที่พัก') ||
        desc.contains('โรงแรม') ||
        desc.contains('hotel') ||
        desc.contains('พัก')) {
      return AppIcons.hotel;
    }
    if (desc.contains('น้ำมัน') ||
        desc.contains('ค่ารถ') ||
        desc.contains('แท็กซี่') ||
        desc.contains('เดินทาง') ||
        desc.contains('transport')) {
      return AppIcons.car;
    }
    if (desc.contains('เคลียร์') || desc.contains('clear')) {
      return AppIcons.checkCircle;
    }
    return AppIcons.receipt;
  }

  /// Category color for the icon background
  Color get categoryColor {
    final desc = description.toLowerCase();
    if (desc.contains('อาหาร') ||
        desc.contains('ข้าว') ||
        desc.contains('กิน') ||
        desc.contains('มื้อ') ||
        desc.contains('restaurant') ||
        desc.contains('แม็กโดนัล') ||
        desc.contains('7-eleven')) {
      return const Color(0xFFFFF3E0); // warm orange bg
    }
    if (desc.contains('ที่พัก') ||
        desc.contains('โรงแรม') ||
        desc.contains('hotel') ||
        desc.contains('พัก')) {
      return const Color(0xFFFFEBEE); // red-ish bg
    }
    if (desc.contains('น้ำมัน') ||
        desc.contains('ค่ารถ') ||
        desc.contains('transport')) {
      return const Color(0xFFE3F2FD); // blue bg
    }
    if (desc.contains('เคลียร์') || desc.contains('clear')) {
      return const Color(0xFFE8F5E9); // green bg
    }
    return const Color(0xFFF3E5F5); // purple bg
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    // Parse payer nested object
    ExpensePayer? payer;
    if (json['payer'] != null) {
      payer = ExpensePayer.fromJson(json['payer'] as Map<String, dynamic>);
    }

    // Parse splits
    final splitsJson = json['expense_splits'] as List<dynamic>? ?? [];
    final splits = splitsJson
        .map((s) => ExpenseSplitSummary.fromJson(s as Map<String, dynamic>))
        .toList();

    final payersJson = json['expense_payers'] as List<dynamic>? ?? [];
    final payers = payersJson
        .map((p) => ExpensePayerInfo.fromJson(p as Map<String, dynamic>))
        .toList();

    return Expense(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      payerId: json['payer_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String? ?? '',
      expenseDate: json['expense_date'] as String? ?? '',
      splitType: json['split_type'] as String? ?? 'equal',
      serviceChargePercent:
          (json['service_charge_percent'] as num?)?.toDouble() ?? 0,
      vatPercent: (json['vat_percent'] as num?)?.toDouble() ?? 0,
      createdBy: json['created_by'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      receiptUrl: json['receipt_url'] as String?,
      payer: payer,
      splits: splits,
      payers: payers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'payer_id': payerId,
      'amount': amount,
      'description': description,
      'expense_date': expenseDate,
      'split_type': splitType,
      'service_charge_percent': serviceChargePercent,
      'vat_percent': vatPercent,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'receipt_url': receiptUrl,
    };
  }
}

class ExpensePayerInfo {
  final String memberId;
  final double amount;
  final String? userId;
  final String? ghostName;
  final String? nickname;
  final String? avatarUrl;

  const ExpensePayerInfo({
    required this.memberId,
    required this.amount,
    this.userId,
    this.ghostName,
    this.nickname,
    this.avatarUrl,
  });

  String get displayName => nickname ?? ghostName ?? 'Unknown';

  factory ExpensePayerInfo.fromJson(Map<String, dynamic> json) {
    final payerMember = json['payer_member'] as Map<String, dynamic>?;
    final profiles = payerMember?['profiles'] as Map<String, dynamic>?;
    return ExpensePayerInfo(
      memberId:
          (json['member_id'] as String?) ??
          (payerMember?['id'] as String? ?? ''),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      userId: payerMember?['user_id'] as String?,
      ghostName: payerMember?['ghost_name'] as String?,
      nickname: profiles?['nickname'] as String?,
      avatarUrl: profiles?['avatar_url'] as String?,
    );
  }
}

/// Payer info from nested join in expense list/detail
class ExpensePayer {
  final String id; // member ID
  final String? userId;
  final String? ghostName;
  final String? nickname;
  final String? avatarUrl;

  const ExpensePayer({
    required this.id,
    this.userId,
    this.ghostName,
    this.nickname,
    this.avatarUrl,
  });

  String get displayName => nickname ?? ghostName ?? 'Unknown';

  factory ExpensePayer.fromJson(Map<String, dynamic> json) {
    final profiles = json['profiles'] as Map<String, dynamic>?;
    return ExpensePayer(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      ghostName: json['ghost_name'] as String?,
      nickname: profiles?['nickname'] as String?,
      avatarUrl: profiles?['avatar_url'] as String?,
    );
  }
}

/// Split summary from the list endpoint (no member profile joined)
class ExpenseSplitSummary {
  final String id;
  final String memberId;
  final double amount;
  final String status; // unpaid, pending, paid

  const ExpenseSplitSummary({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.status,
  });

  factory ExpenseSplitSummary.fromJson(Map<String, dynamic> json) {
    return ExpenseSplitSummary(
      id: json['id'] as String,
      memberId: json['member_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String? ?? 'unpaid',
    );
  }
}
