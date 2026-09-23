import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

class BelvonSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const BelvonSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.title),
            if (subtitle != null) ...[
              const SizedBox(height: 5),
              Text(subtitle!, style: AppTextStyles.body),
            ],
          ],
        ),
      ),
      if (trailing != null) trailing!,
    ],
  );
}
