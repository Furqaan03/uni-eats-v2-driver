import 'package:flutter_test/flutter_test.dart';
import 'package:uni_eats_driver/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const UniEatsDriverApp());
    expect(find.byType(UniEatsDriverApp), findsOneWidget);
  });
}
