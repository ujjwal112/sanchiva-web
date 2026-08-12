import 'package:flutter_test/flutter_test.dart';
import 'package:sanchiva_mobile/main.dart';

void main() {
  testWidgets('App boots', (tester) async {
    await tester.pumpWidget(const SanchivaApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SanchivaApp), findsOneWidget);
  });
}
