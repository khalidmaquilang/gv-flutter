import 'package:flutter/material.dart';
import 'package:test_flutter/core/theme/app_theme.dart';

class NeonBorderContainer extends StatelessWidget {
  final Widget child;
  final double borderWidth;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final BoxShape shape;

  const NeonBorderContainer({
    super.key,
    required this.child,
    this.borderWidth = 2.0,
    this.borderRadius = 8.0,
    this.padding,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(borderRadius),
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.neonPink.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(-2, -2),
          ),
          BoxShadow(
            color: AppColors.neonCyan.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Container(
        margin: EdgeInsets.all(borderWidth),
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.deepVoid, // Inner background
          shape: shape,
          borderRadius: shape == BoxShape.circle
              ? null
              : BorderRadius.circular(borderRadius - borderWidth),
        ),
        child: child,
      ),
    );
  }
}
