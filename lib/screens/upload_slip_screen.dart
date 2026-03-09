import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/widgets/rounded_button.dart';

class UploadSlipScreen extends StatefulWidget {
  const UploadSlipScreen({super.key});

  @override
  State<UploadSlipScreen> createState() => _UploadSlipScreenState();
}

class _UploadSlipScreenState extends State<UploadSlipScreen> {
  bool _isUploading = false;
  bool _hasImage = false;

  void _pickImage() {
    // Mock pick image
    setState(() {
      _hasImage = true;
    });
  }

  void _uploadSlip() async {
    setState(() => _isUploading = true);
    // Simulate upload
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isUploading = false);
      // Show Result or Pop
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งสลิปเรียบร้อยแล้ว! (Mock)')),
      );
      context.go('/groups'); // Return to groups or detail
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แนบสลิป'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 400,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _hasImage
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          const Center(
                            child: Icon(
                              AppIcons.image,
                              size: 60,
                              color: Colors.blue,
                            ),
                          ), // Placeholder for actual image
                          Positioned(
                            top: 10,
                            right: 10,
                            child: IconButton(
                              icon: const Icon(
                                AppIcons.close,
                                color: Colors.red,
                              ),
                              onPressed: () =>
                                  setState(() => _hasImage = false),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            AppIcons.imagePlus,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'แตะเพื่อเลือกรูปสลิป',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
            _isUploading
                ? const CircularProgressIndicator()
                : RoundedButton(
                    text: 'ยืนยันการส่ง',
                    backgroundColor: _hasImage
                        ? const Color(0xFF81CEF2)
                        : Colors.grey,
                    textColor: Colors.white,
                    onPressed: _hasImage ? _uploadSlip : () {},
                  ),
          ],
        ),
      ),
    );
  }
}
