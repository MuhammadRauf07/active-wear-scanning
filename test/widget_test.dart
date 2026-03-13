import 'package:flutter_test/flutter_test.dart';

import 'package:active_wear_scanning/app.dart';

void main() {
  testWidgets('Scanning Sections screen displays', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('Active Ware'), findsOneWidget);
  });
}
