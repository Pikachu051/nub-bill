import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/app.dart';
import 'package:nubbill/config/supabase_config.dart';

// Provider definition moved to auth_repository.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const ProviderScope(child: App()));
}
