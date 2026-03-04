import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';

/// Trip category enum matching backend
enum TripCategory {
  travel,
  accommodation,
  food,
  romance,
  other;

  /// Get display name in Thai
  String get displayName {
    switch (this) {
      case TripCategory.travel:
        return 'ออกทริป';
      case TripCategory.accommodation:
        return 'ที่พัก';
      case TripCategory.food:
        return 'อาหาร';
      case TripCategory.romance:
        return 'หวานใจ';
      case TripCategory.other:
        return 'อื่นๆ';
    }
  }

  /// Get emoji for category
  String get emoji {
    switch (this) {
      case TripCategory.travel:
        return '✈️';
      case TripCategory.accommodation:
        return '🏠';
      case TripCategory.food:
        return '🍽️';
      case TripCategory.romance:
        return '❤️';
      case TripCategory.other:
        return '📦';
    }
  }

  /// Get icon for category
  IconData get icon {
    switch (this) {
      case TripCategory.travel:
        return AppIcons.flight;
      case TripCategory.accommodation:
        return AppIcons.hotel;
      case TripCategory.food:
        return AppIcons.restaurant;
      case TripCategory.romance:
        return AppIcons.favorite;
      case TripCategory.other:
        return AppIcons.category;
    }
  }

  /// Parse from string
  static TripCategory fromString(String? value) {
    switch (value) {
      case 'travel':
        return TripCategory.travel;
      case 'accommodation':
        return TripCategory.accommodation;
      case 'food':
        return TripCategory.food;
      case 'romance':
        return TripCategory.romance;
      default:
        return TripCategory.other;
    }
  }
}

/// Member role enum
enum MemberRole {
  admin,
  member;

  static MemberRole fromString(String? value) {
    return value == 'admin' ? MemberRole.admin : MemberRole.member;
  }
}

/// Trip model matching backend TripWithBalance response
class Trip {
  final String id;
  final String name;
  final TripCategory category;
  final String joinCode;
  final String? coverUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional fields from TripWithBalance
  final double balance;
  final int memberCount;
  final MemberRole myRole;

  const Trip({
    required this.id,
    required this.name,
    required this.category,
    required this.joinCode,
    this.coverUrl,
    this.startDate,
    this.endDate,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.balance = 0,
    this.memberCount = 0,
    this.myRole = MemberRole.member,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      name: json['name'] as String,
      category: TripCategory.fromString(json['category'] as String?),
      joinCode: json['join_code'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      memberCount: json['member_count'] as int? ?? 0,
      myRole: MemberRole.fromString(json['my_role'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'join_code': joinCode,
      'cover_url': coverUrl,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'balance': balance,
      'member_count': memberCount,
      'my_role': myRole.name,
    };
  }
}
