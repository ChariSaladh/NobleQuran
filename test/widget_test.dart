import 'package:flutter_test/flutter_test.dart';
import 'package:noblequran/main.dart';

void main() {
  testWidgets('App should render home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NobleQuranApp());

    // Verify that the app title is present
    expect(find.text('Noble Quran'), findsOneWidget);
  });
}
