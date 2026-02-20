import 'package:flutter/material.dart';
import '../app/app_theme.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator(
      color: AppColors.neonBlue,
      strokeWidth: 2.5,
    );
  }
}
