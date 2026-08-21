import 'package:flutter/material.dart';

import '../../../../core/theme/spark_theme.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 24,
    this.showStatus = false,
    this.statusColor,
  });

  final String imageUrl;
  final double radius;
  final bool showStatus;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2 + 4,
      height: radius * 2 + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: radius * 2,
            height: radius * 2,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: SparkColors.of(context).card,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  // 阴影固定用黑色系：ink 在暗色下是亮色，会变成光晕。
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.40
                        : 0.12,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: SparkColors.of(context).surfaceMuted,
                  child: Icon(
                    Icons.person_rounded,
                    color: SparkColors.of(context).muted,
                  ),
                ),
              ),
            ),
          ),
          if (showStatus)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: radius * 0.48,
                height: radius * 0.48,
                decoration: BoxDecoration(
                  color: statusColor ?? SparkColors.of(context).primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: SparkColors.of(context).card,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
