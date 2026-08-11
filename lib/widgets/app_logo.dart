import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.width});

  static const String assetPath = 'assets/images/app_logo.png';

  final double? width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'شعار مساعد طلبة الثانوية',
    );
  }
}
