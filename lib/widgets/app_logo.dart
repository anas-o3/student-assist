import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.width});

  static const String assetPath = 'assets/images/app_logo.png';

  final double? width;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = width == null
        ? null
        : (width! * devicePixelRatio).round();

    return Image.asset(
      assetPath,
      width: width,
      fit: BoxFit.contain,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'شعار مساعد طلبة الثانوية',
    );
  }
}
