import 'package:flutter/material.dart';
import '../theme/app_dimensions.dart';

class BelvonResponsive extends StatelessWidget {
  final Widget mobile;
  final Widget desktop;
  final double breakpoint;

  const BelvonResponsive({
    super.key,
    required this.mobile,
    required this.desktop,
    this.breakpoint = 800,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimensions.contentMaxWidth),
        child: width >= breakpoint ? desktop : mobile,
      ),
    );
  }
}
