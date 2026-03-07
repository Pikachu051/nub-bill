import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';

enum ExpenseCategory { home, food, bill }

extension ExpenseCategoryX on ExpenseCategory {
  static ExpenseCategory fromApi(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'home':
      case 'บ้าน':
        return ExpenseCategory.home;
      case 'food':
      case 'อาหาร':
        return ExpenseCategory.food;
      case 'bill':
      case 'บิล':
      default:
        return ExpenseCategory.bill;
    }
  }

  String get apiValue {
    switch (this) {
      case ExpenseCategory.home:
        return 'home';
      case ExpenseCategory.food:
        return 'food';
      case ExpenseCategory.bill:
        return 'bill';
    }
  }

  String get label {
    switch (this) {
      case ExpenseCategory.home:
        return 'บ้าน';
      case ExpenseCategory.food:
        return 'อาหาร';
      case ExpenseCategory.bill:
        return 'บิล';
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.home:
        return const Color(0xFFF2DA89);
      case ExpenseCategory.food:
        return const Color(0xFFF4BDDB);
      case ExpenseCategory.bill:
        return const Color(0xFFA1A1A2);
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.home:
        return AppIcons.home;
      case ExpenseCategory.food:
        return AppIcons.restaurant;
      case ExpenseCategory.bill:
        return AppIcons.receipt;
    }
  }
}
