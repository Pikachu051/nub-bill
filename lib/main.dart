import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/app.dart';

// Provider definition moved to auth_repository.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase unavailable — push notifications disabled, app continues normally
  }
  runApp(const ProviderScope(child: App()));
}
