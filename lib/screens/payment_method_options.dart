import 'package:flutter/material.dart';

class PaymentChannelOption {
  final String id;
  final String label;
  final String displayName;
  final String assetPath;
  final String type;

  const PaymentChannelOption({
    required this.id,
    required this.label,
    required this.displayName,
    required this.assetPath,
    required this.type,
  });
}

class PaymentChannelOptions {
  static const kasikorn = PaymentChannelOption(
    id: 'kasikorn',
    label: 'กสิกรไทย',
    displayName: 'ธนาคารกสิกรไทย',
    assetPath: 'assets/images/kasikorn.png',
    type: 'bank_account',
  );

  static const scb = PaymentChannelOption(
    id: 'scb',
    label: 'ไทยพาณิชย์',
    displayName: 'ธนาคารไทยพาณิชย์',
    assetPath: 'assets/images/scb.png',
    type: 'bank_account',
  );

  static const bangkok = PaymentChannelOption(
    id: 'bangkok',
    label: 'กรุงเทพ',
    displayName: 'ธนาคารกรุงเทพ',
    assetPath: 'assets/images/bangkok.png',
    type: 'bank_account',
  );

  static const krungthai = PaymentChannelOption(
    id: 'krungthai',
    label: 'กรุงไทย',
    displayName: 'ธนาคารกรุงไทย',
    assetPath: 'assets/images/krungthai.png',
    type: 'bank_account',
  );

  static const krungsri = PaymentChannelOption(
    id: 'krungsri',
    label: 'กรุงศรี',
    displayName: 'ธนาคารกรุงศรี',
    assetPath: 'assets/images/krungsri.png',
    type: 'bank_account',
  );

  static const promptPay = PaymentChannelOption(
    id: 'promptpay',
    label: 'พร้อมเพย์',
    displayName: 'พร้อมเพย์',
    assetPath: 'assets/images/prompt-pay.png',
    type: 'promptpay',
  );

  static const list = <PaymentChannelOption>[
    kasikorn,
    scb,
    bangkok,
    krungthai,
    krungsri,
    promptPay,
  ];

  static PaymentChannelOption byId(String id) {
    return list.firstWhere((option) => option.id == id, orElse: () => kasikorn);
  }

  static PaymentChannelOption? byBankName(String? bankName) {
    if (bankName == null || bankName.trim().isEmpty) return null;
    final normalized = bankName.toLowerCase().replaceAll(' ', '');

    if (normalized.contains('กสิกร') || normalized.contains('kasikorn')) {
      return kasikorn;
    }
    if (normalized.contains('ไทยพาณิชย์') || normalized.contains('scb')) {
      return scb;
    }
    if (normalized.contains('กรุงเทพ') || normalized.contains('bangkok')) {
      return bangkok;
    }
    if (normalized.contains('กรุงไทย') || normalized.contains('krungthai')) {
      return krungthai;
    }
    if (normalized.contains('กรุงศรี') || normalized.contains('krungsri')) {
      return krungsri;
    }
    if (normalized.contains('พร้อมเพย์') || normalized.contains('promptpay')) {
      return promptPay;
    }

    return null;
  }

  static String bankNameForBackend(PaymentChannelOption option) {
    switch (option.id) {
      case 'kasikorn':
        return 'กสิกรไทย';
      case 'scb':
        return 'ไทยพาณิชย์';
      case 'bangkok':
        return 'กรุงเทพ';
      case 'krungthai':
        return 'กรุงไทย';
      case 'krungsri':
        return 'กรุงศรี';
      case 'promptpay':
        return 'พร้อมเพย์';
      default:
        return option.label;
    }
  }

  static Widget bankIcon(
    PaymentChannelOption option, {
    double size = 28,
    Color background = Colors.white,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(option.assetPath, fit: BoxFit.cover),
    );
  }
}
