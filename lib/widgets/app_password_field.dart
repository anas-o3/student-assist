import 'package:flutter/material.dart';

class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.hintText,
    required this.textInputAction,
    this.showPasswordTooltip = 'إظهار كلمة المرور',
    this.hidePasswordTooltip = 'إخفاء كلمة المرور',
  });

  final String hintText;
  final TextInputAction textInputAction;
  final String showPasswordTooltip;
  final String hidePasswordTooltip;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: !_isPasswordVisible,
      textInputAction: widget.textInputAction,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _isPasswordVisible
              ? widget.hidePasswordTooltip
              : widget.showPasswordTooltip,
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
          icon: Icon(
            _isPasswordVisible
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}
