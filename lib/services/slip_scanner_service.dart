import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:nubbill/services/promptpay_parser.dart';

class SlipScannerService {
  Future<SlipQrData?> scanSlipImage(String imagePath) async {
    final scanner = BarcodeScanner(
      formats: [BarcodeFormat.qrCode],
    );

    try {
      final image = InputImage.fromFilePath(imagePath);
      final barcodes = await scanner.processImage(image);

      for (final barcode in barcodes) {
        final raw = barcode.rawValue;
        if (raw == null || raw.trim().isEmpty) {
          continue;
        }

        final parsed = PromptPayParser.parse(raw);
        if (parsed != null) {
          return parsed;
        }

        // Keep raw payload as fallback so backend can parse/verify as source-of-truth.
        return SlipQrData(
          amount: null,
          receiverId: null,
          transactionRef: null,
          rawPayload: raw.trim(),
        );
      }

      return null;
    } finally {
      await scanner.close();
    }
  }
}
