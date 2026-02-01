import 'package:flutter/material.dart';

class RoundedButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color textColor;
  final bool outlined;

  const RoundedButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.backgroundColor,
    required this.textColor,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
            side: outlined ? BorderSide(color: textColor) : BorderSide.none,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'LINESeedSansTH',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textColor,
            height: 1.2,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
