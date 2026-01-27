import 'package:flutter/material.dart';

class TripCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color backgroundColor;
  final Color mainColor;

  const TripCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.backgroundColor,
    required this.mainColor,
  });
}