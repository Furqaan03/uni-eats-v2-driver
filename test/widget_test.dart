import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uni_eats_driver/core/theme/theme_provider.dart';
import 'package:uni_eats_driver/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // The app reads ThemeProvider in build(), so it must be provided — mirrors
    // how main() wires it. Only ThemeProvider is needed for the first frame
    // (the splash screen reads no other providers).
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: const UniEatsDriverApp(),
      ),
    );
    expect(find.byType(UniEatsDriverApp), findsOneWidget);
  });
}
