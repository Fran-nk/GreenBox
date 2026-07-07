import 'package:flutter_test/flutter_test.dart';
import 'package:greenbox/main.dart';
import 'package:greenbox/data/repositories/mock_greenbox_repository.dart';

void main() {
  testWidgets('Dashboard renders greeting', (WidgetTester tester) async {
    await tester.pumpWidget(
      GreenBoxApp(repository: MockGreenBoxRepository()),
    );

    // Verify greeting is displayed
    expect(find.textContaining('Hola'), findsOneWidget);
  });
}
