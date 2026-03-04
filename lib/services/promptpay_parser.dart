class SlipQrData {
  final double? amount;
  final String? receiverId;
  final String? transactionRef;
  final String rawPayload;

  const SlipQrData({
    required this.amount,
    required this.receiverId,
    required this.transactionRef,
    required this.rawPayload,
  });
}

class PromptPayParser {
  static SlipQrData? parse(String rawPayload) {
    final payload = rawPayload.trim();
    if (payload.isEmpty || payload.length < 8) {
      return null;
    }

    if (!_isValidCrc(payload)) {
      return null;
    }

    final rootTags = _parseTlv(payload);
    if (rootTags.isEmpty) {
      return null;
    }

    final amount = _parseAmount(rootTags['54']);
    final receiverId = _extractReceiverId(rootTags);
    final transactionRef = _extractTransactionRef(rootTags['62']);

    if ((receiverId == null || receiverId.isEmpty) &&
        (transactionRef == null || transactionRef.isEmpty) &&
        amount == null) {
      return null;
    }

    return SlipQrData(
      amount: amount,
      receiverId: receiverId,
      transactionRef: transactionRef,
      rawPayload: payload,
    );
  }

  static Map<String, String> _parseTlv(String input) {
    final tags = <String, String>{};
    var index = 0;

    while (index + 4 <= input.length) {
      final tag = input.substring(index, index + 2);
      final lengthString = input.substring(index + 2, index + 4);
      final length = int.tryParse(lengthString);
      if (length == null || length < 0) {
        break;
      }

      final valueStart = index + 4;
      final valueEnd = valueStart + length;
      if (valueEnd > input.length) {
        break;
      }

      final value = input.substring(valueStart, valueEnd);
      tags[tag] = value;
      index = valueEnd;
    }

    return tags;
  }

  static double? _parseAmount(String? amountRaw) {
    if (amountRaw == null || amountRaw.isEmpty) {
      return null;
    }
    return double.tryParse(amountRaw);
  }

  static String? _extractReceiverId(Map<String, String> rootTags) {
    final merchantInfoRaw = rootTags['29'] ?? rootTags['30'];
    if (merchantInfoRaw == null || merchantInfoRaw.isEmpty) {
      return null;
    }

    final merchantTags = _parseTlv(merchantInfoRaw);
    final aid = merchantTags['00'];
    if (aid != 'A000000677010111') {
      return null;
    }

    final phoneOrTaxId = merchantTags['01'];
    final eWalletId = merchantTags['02'];
    final candidate = phoneOrTaxId ?? eWalletId;
    if (candidate == null || candidate.isEmpty) {
      return null;
    }

    return candidate.replaceAll(RegExp(r'\D'), '');
  }

  static String? _extractTransactionRef(String? additionalDataRaw) {
    if (additionalDataRaw == null || additionalDataRaw.isEmpty) {
      return null;
    }

    final additionalTags = _parseTlv(additionalDataRaw);
    final ref = additionalTags['05'];
    if (ref == null || ref.trim().isEmpty) {
      return null;
    }

    return ref.trim();
  }

  static bool _isValidCrc(String payload) {
    final crcTagIndex = payload.lastIndexOf('6304');
    if (crcTagIndex <= 0 || crcTagIndex + 8 > payload.length) {
      return false;
    }

    final suppliedCrc = payload.substring(crcTagIndex + 4, crcTagIndex + 8);
    final withoutCrcValue = payload.substring(0, crcTagIndex + 4);
    final computed = _crc16Ccitt(withoutCrcValue);

    return suppliedCrc.toUpperCase() == computed;
  }

  static String _crc16Ccitt(String input) {
    var crc = 0xFFFF;

    for (final unit in input.codeUnits) {
      crc ^= (unit << 8);
      for (var i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc <<= 1;
        }
        crc &= 0xFFFF;
      }
    }

    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
