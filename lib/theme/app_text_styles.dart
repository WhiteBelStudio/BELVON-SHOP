import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  static const display = TextStyle(
    fontSize: 30,
    height: 1.08,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
  );

  static const title = TextStyle(
    fontSize: 22,
    height: 1.15,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 15,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: .7,
    color: AppColors.textSecondary,
  );
}

