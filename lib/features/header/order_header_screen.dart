import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:flutter/material.dart';

class OrderHeaderScreen extends StatelessWidget {
  const OrderHeaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomInspectionHeader(
              heading: 'Order Header',
              isShowBackIcon: true,
              topPadding: 0,
              horizontalPadding: 12,
            ),
            const Expanded(
              child: Center(
                child: Text('Order Header'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
