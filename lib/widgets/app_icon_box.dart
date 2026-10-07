import 'package:flutter/material.dart';
import '../core/app_spacing.dart';

class AppIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const AppIconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Icon(icon, size: size * 0.48, color: color),
    );
  }
}
