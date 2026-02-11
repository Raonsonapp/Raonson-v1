import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: RColors.bg,
      body: Center(
        child: Text('Search', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
