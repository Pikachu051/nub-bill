import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nubbill/config/theme.dart';
import 'package:nubbill/services/friend_service.dart';
import 'package:nubbill/widgets/half_width_tab_indicator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Add Friend Modal with QR Code and Search tabs
/// Matches the design from prototype "Add Friend Popup.png"
class AddFriendModal extends ConsumerStatefulWidget {
  const AddFriendModal({super.key});

  @override
  ConsumerState<AddFriendModal> createState() => _AddFriendModalState();
}

class _AddFriendModalState extends ConsumerState<AddFriendModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.settings_outlined, color: Colors.grey[400]),
                  onPressed: () {
                    // Settings action (placeholder)
                  },
                ),
                const Expanded(
                  child: Text(
                    'เพิ่มเพื่อน',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: const HalfWidthTabIndicator(
              color: AppTheme.primaryColor,
              thickness: 2,
              widthFactor: 0.5,
              radius: 2,
            ),
            tabs: const [
              Tab(text: 'คิวอาร์โค้ด'),
              Tab(text: 'ค้นหา'),
            ],
          ),
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [_QrCodeTab(), _SearchTab()],
            ),
          ),
        ],
      ),
    );
  }
}

/// QR Code Tab with toggle between Scan and My QR
class _QrCodeTab extends ConsumerStatefulWidget {
  const _QrCodeTab();

  @override
  ConsumerState<_QrCodeTab> createState() => _QrCodeTabState();
}

class _QrCodeTabState extends ConsumerState<_QrCodeTab> {
  bool _isMyQrMode = true; // true = My QR, false = Scan
  final GlobalKey _qrKey = GlobalKey();
  MobileScannerController? _scannerController;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  String get _deepLink => 'nubbill://friend/add/$_currentUserId';

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _initScanner() {
    if (_scannerController != null) return;
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      autoStart: true,
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _deepLink));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('คัดลอกลิงก์แล้ว')));
    }
  }

  Future<void> _shareQr() async {
    await Share.share(
      'เพิ่มฉันเป็นเพื่อนบน NubBill!\n$_deepLink',
      subject: 'เพิ่มเพื่อน NubBill',
    );
  }

  Future<void> _saveQr() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to temp directory and share
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/nubbill_qr_code.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'NubBill QR Code');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('บันทึก QR Code แล้ว')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ไม่สามารถบันทึก QR Code: $e')));
      }
    }
  }

  Future<void> _onQrDetected(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final scannedValue = barcode.rawValue!;

    // Parse the deep link to extract user ID
    String? userId;
    if (scannedValue.startsWith('nubbill://friend/add/')) {
      userId = scannedValue.replaceFirst('nubbill://friend/add/', '');
    } else {
      // Try to parse as raw UUID
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      if (uuidRegex.hasMatch(scannedValue)) {
        userId = scannedValue;
      }
    }

    if (userId == null || userId == _currentUserId) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('QR Code ไม่ถูกต้อง')));
      }
      return;
    }

    // Stop scanning
    _scannerController?.stop();

    // Send friend request
    try {
      await ref.read(friendServiceProvider).sendRequestById(userId);
      ref.invalidate(pendingRequestsProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ส่งคำขอเป็นเพื่อนแล้ว!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
        _scannerController?.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Toggle buttons
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _initScanner();
                    setState(() => _isMyQrMode = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_isMyQrMode ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: !_isMyQrMode
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 20,
                          color: !_isMyQrMode
                              ? AppTheme.primaryColor
                              : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'สแกน',
                          style: TextStyle(
                            color: !_isMyQrMode
                                ? AppTheme.primaryColor
                                : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isMyQrMode = true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _isMyQrMode
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_2,
                          size: 20,
                          color: _isMyQrMode
                              ? AppTheme.primaryColor
                              : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'คิวอาร์ของฉัน',
                          style: TextStyle(
                            color: _isMyQrMode
                                ? AppTheme.primaryColor
                                : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Content area
        Expanded(child: _isMyQrMode ? _buildMyQrView() : _buildScanView()),
      ],
    );
  }

  Widget _buildMyQrView() {
    return Column(
      children: [
        // QR Code
        Expanded(
          child: Center(
            child: RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: _deepLink,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 16, 40, 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.link,
                label: 'คัดลอกลิงก์',
                onTap: _copyLink,
              ),
              _buildActionButton(
                icon: Icons.ios_share,
                label: 'แชร์',
                onTap: _shareQr,
              ),
              _buildActionButton(
                icon: Icons.download,
                label: 'บันทึก',
                onTap: _saveQr,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 28),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildScanView() {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: _scannerController == null
                ? const Center(child: CircularProgressIndicator())
                : MobileScanner(
                    controller: _scannerController,
                    onDetect: _onQrDetected,
                    errorBuilder: (context, error) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.camera_alt_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'ไม่สามารถเปิดกล้องได้',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'กรุณาอนุญาตการเข้าถึงกล้องในการตั้งค่า',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'สแกน QR Code ของเพื่อนเพื่อเพิ่มเพื่อน',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

/// Search Tab for email search
class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab();

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  final _searchController = TextEditingController();
  List<UserSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _isSending = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await ref.read(friendServiceProvider).searchUsers(query);
      setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendRequest(String userId) async {
    setState(() => _isSending = true);
    try {
      await ref.read(friendServiceProvider).sendRequestById(userId);
      ref.invalidate(pendingRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ส่งคำขอเป็นเพื่อนแล้ว!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'ค้นหาด้วยอีเมล',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _search,
                    ),
            ),
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          Text(
            'กรอกอีเมลที่ถูกต้องเพื่อค้นหาผู้ใช้',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 16),
          // Search results
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.email_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'ค้นหาเพื่อนด้วยอีเมล',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('ไม่พบผู้ใช้', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              'ตรวจสอบอีเมลและลองอีกครั้ง',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return Card(
          elevation: 0,
          color: Colors.grey[50],
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Text(
                          user.nickname.isNotEmpty
                              ? user.nickname[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: AppTheme.primaryColor),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nickname,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (user.email != null)
                        Text(
                          user.email!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildUserActionButton(user),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserActionButton(UserSearchResult user) {
    if (user.friendshipStatus == 'accepted') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'เป็นเพื่อนแล้ว',
          style: TextStyle(color: Colors.green, fontSize: 12),
        ),
      );
    } else if (user.friendshipStatus == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          user.isPendingFromMe ? 'รอตอบรับ' : 'มีคำขอ',
          style: const TextStyle(color: Colors.orange, fontSize: 12),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: _isSending ? null : () => _sendRequest(user.id),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: _isSending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('เพิ่มเพื่อน'),
      );
    }
  }
}
