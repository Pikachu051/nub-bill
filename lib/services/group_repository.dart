import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nubbill/config/supabase_config.dart';
import 'package:nubbill/models/group_model.dart';
import 'package:nubbill/services/auth_repository.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(SupabaseConfig.client, ref);
});

class GroupRepository {
  final SupabaseClient _client;
  final Ref _ref;

  GroupRepository(this._client, this._ref);

  Future<List<Group>> getGroups() async {
    final user = _ref.read(authRepositoryProvider).currentUser;
    if (user == null) return [];

    // Assuming we have a 'groups' table and a 'group_members' table?
    // Or just 'groups' if user is checking owned groups + joined groups.
    // For now, let's fetch from 'groups' table.
    // Ideally:
    // final response = await _client.from('groups').select()...;
    // But since backend is not fully set up, I will Mock return or try to fetch.
    // I'll try to fetch, and catch error to return empty list if table doesn't exist.

    try {
      final response = await _client
          .from('groups')
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((e) => Group.fromJson(e)).toList();
    } catch (e) {
      // Fallback/Mock for development if backend table is missing
      return [];
    }
  }

  Future<void> createGroup(String name) async {
    final user = _ref.read(authRepositoryProvider).currentUser;
    if (user == null) throw Exception('User not logged in');

    await _client.from('groups').insert({
      'name': name,
      'created_by': user.id,
      'owner_id': user.id, // Assuming owner_id column
    });
  }
}
