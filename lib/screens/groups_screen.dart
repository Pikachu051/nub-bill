import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/providers/groups_provider.dart';
import 'package:nubbill/widgets/group_card.dart';
import 'package:nubbill/widgets/retry_error_state.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'กลุ่มของฉัน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.groups, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'ยังไม่มีกลุ่ม',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.push('/groups/create'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF81CEF2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('สร้างกลุ่มใหม่'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return GroupCard(group: group);
            },
          );
        },
        error: (err, stack) => RetryErrorState(
          error: err,
          onRetry: () => ref.invalidate(groupsProvider),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/groups/create'),
        backgroundColor: const Color(0xFF81CEF2),
        child: const Icon(AppIcons.add, color: Colors.white),
      ),
    );
  }
}
