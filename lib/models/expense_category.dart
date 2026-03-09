import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';

enum ExpenseCategory { home, food, bill, shopping, travel, health, pet }

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
        return ExpenseCategory.bill;
      case 'shopping':
      case 'ช้อปปิ้ง':
        return ExpenseCategory.shopping;
      case 'travel':
      case 'เดินทาง':
        return ExpenseCategory.travel;
      case 'health':
      case 'สุขภาพ':
        return ExpenseCategory.health;
      case 'pet':
      case 'pets':
      case 'สัตว์เลี้ยง':
        return ExpenseCategory.pet;
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
      case ExpenseCategory.shopping:
        return 'shopping';
      case ExpenseCategory.travel:
        return 'travel';
      case ExpenseCategory.health:
        return 'health';
      case ExpenseCategory.pet:
        return 'pet';
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
      case ExpenseCategory.shopping:
        return 'ช้อปปิ้ง';
      case ExpenseCategory.travel:
        return 'เดินทาง';
      case ExpenseCategory.health:
        return 'สุขภาพ';
      case ExpenseCategory.pet:
        return 'สัตว์เลี้ยง';
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.home:
        return const Color(0xFFF4BDDB);
      case ExpenseCategory.food:
        return const Color(0xFFF2DA89);
      case ExpenseCategory.bill:
        return const Color(0xFFA1A1A2);
      case ExpenseCategory.shopping:
        return const Color(0xFFC9DDF2);
      case ExpenseCategory.travel:
        return const Color(0xFFBFE6DF);
      case ExpenseCategory.health:
        return const Color(0xFFBFDDB7);
      case ExpenseCategory.pet:
        return const Color(0xFFF2D3B3);
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
      case ExpenseCategory.shopping:
        return AppIcons.shopping;
      case ExpenseCategory.travel:
        return AppIcons.travel;
      case ExpenseCategory.health:
        return AppIcons.health;
      case ExpenseCategory.pet:
        return AppIcons.pet;
    }
  }
}
