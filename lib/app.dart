import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/scanning_sections/presentation/scanning_sections_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const ScanningSectionsScreen(),
    );
  }
}
