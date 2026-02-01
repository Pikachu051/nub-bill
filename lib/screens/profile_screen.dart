import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nubbill/services/auth_repository.dart';
import 'package:nubbill/services/profile_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();

    // Show bottom sheet to choose camera or gallery
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'เลือกรูปโปรไฟล์',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF81CEF2)),
                title: const Text('ถ่ายรูป'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF81CEF2),
                ),
                title: const Text('เลือกจากแกลเลอรี'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingAvatar = true);

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      final fileExt = pickedFile.path.split('.').last;
      final fileName = '$userId/avatar.$fileExt';
      final file = File(pickedFile.path);

      // Upload to Supabase Storage
      await supabase.storage
          .from('avatars')
          .upload(fileName, file, fileOptions: const FileOptions(upsert: true));

      // Get public URL
      final publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

      // Update profile with new avatar URL
      await supabase
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', userId);

      // Refresh profile
      ref.invalidate(myProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อัพโหลดรูปโปรไฟล์สำเร็จ!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final user = ref.watch(authRepositoryProvider).currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            _buildFallbackProfile(context, ref, user, err.toString()),
        data: (profile) => _buildProfileContent(context, ref, profile),
      ),
    );
  }

  Widget _buildFallbackProfile(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    String error,
  ) {
    final nickname = user?.userMetadata?['nickname'] ?? 'ผู้ใช้งาน';

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 60),
          _buildAvatar(nickname, null),
          const SizedBox(height: 16),
          Text(
            nickname,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(user?.email ?? '', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Text(
            'ไม่สามารถโหลดข้อมูลได้: $error',
            style: TextStyle(color: Colors.red[300], fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(myProfileProvider),
            child: const Text('ลองอีกครั้ง'),
          ),
          const SizedBox(height: 32),
          _buildSettingsList(context, ref),
        ],
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) {
    final nickname = profile.nickname ?? 'ผู้ใช้งาน';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myProfileProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 60),
            _buildAvatar(nickname, profile.avatarUrl),
            const SizedBox(height: 16),
            Text(
              nickname,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              profile.email ?? '',
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 32),

            // Stats Row from API
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'กลุ่มทั้งหมด',
                    profile.stats.totalTrips.toString(),
                  ),
                  _buildStatItem(
                    'เพื่อน',
                    profile.stats.totalFriends.toString(),
                  ),
                  _buildStatItem(
                    'รายการ',
                    profile.stats.totalExpenses.toString(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Balance Summary Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF81CEF2),
                    const Color(0xFF81CEF2).withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBalanceItem(
                    'รับคืน',
                    profile.stats.totalReceived,
                    Colors.white,
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  _buildBalanceItem(
                    'จ่ายออก',
                    profile.stats.totalPaid,
                    Colors.white,
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  _buildBalanceItem(
                    'ยอดสุทธิ',
                    profile.stats.netBalance,
                    profile.stats.netBalance >= 0
                        ? Colors.green[100]!
                        : Colors.red[100]!,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Divider(thickness: 8, color: Color(0xFFF5F5F5)),

            _buildSettingsList(context, ref),

            const SizedBox(height: 40),
            Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.grey[300], fontSize: 12),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String nickname, String? avatarUrl) {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF81CEF2).withValues(alpha: 0.2),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: _isUploadingAvatar
                ? const CircularProgressIndicator(color: Color(0xFF81CEF2))
                : avatarUrl == null
                ? Text(
                    nickname.isNotEmpty ? nickname[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 40,
                      color: Color(0xFF81CEF2),
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: _isUploadingAvatar
                      ? Colors.grey
                      : const Color(0xFF81CEF2),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _buildSettingItem(
          icon: Icons.person_outline,
          title: 'แก้ไขข้อมูลส่วนตัว',
          onTap: () {},
        ),
        _buildSettingItem(
          icon: Icons.qr_code,
          title: 'QR Code ของฉัน',
          onTap: () {},
        ),
        _buildSettingItem(
          icon: Icons.notifications_none,
          title: 'การแจ้งเตือน',
          onTap: () {},
        ),
        _buildSettingItem(
          icon: Icons.credit_card,
          title: 'จัดการบัญชี / พร้อมเพย์',
          onTap: () {},
        ),

        const Divider(),
        _buildSettingItem(
          icon: Icons.help_outline,
          title: 'ช่วยเหลือ & สนับสนุน',
          onTap: () {},
        ),

        _buildSettingItem(
          icon: Icons.logout,
          title: 'ออกจากระบบ',
          color: Colors.red,
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('ออกจากระบบ'),
                content: const Text('คุณแน่ใจหรือไม่ที่จะออกจากระบบ?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                    child: const Text(
                      'ออกจากระบบ',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildBalanceItem(String label, double amount, Color textColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '฿${amount.abs().toStringAsFixed(0)}',
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.black87,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: color == Colors.red ? Colors.red : const Color(0xFF81CEF2),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
      onTap: onTap,
    );
  }
}
