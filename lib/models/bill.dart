import 'package:flutter/material.dart';

class Bill {
  final String id;
  final String title;
  final String category;
  final IconData categoryIcon;
  final double totalAmount;
  final double yourAmount;
  final String? status; // null = normal, "paid" = paid, "cleared" = cleared
  final String? statusLabel;
  final DateTime date;

  const Bill({
    required this.id,
    required this.title,
    required this.category,
    required this.categoryIcon,
    required this.totalAmount,
    required this.yourAmount,
    this.status,
    this.statusLabel,
    required this.date,
  });
}