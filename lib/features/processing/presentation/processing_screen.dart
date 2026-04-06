import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:flutter/material.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const CustomInspectionHeader(
              heading: 'Processing',
              subtitle: 'WIP transaction',
              isShowBackIcon: true,
              topPadding: 10,
              horizontalPadding: 12,
            ),
            const Expanded(
              child: Center(
                child: Text('Processing Flow Coming Soon'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
