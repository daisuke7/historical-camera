import 'package:flutter_test/flutter_test.dart';

import 'package:historical_camera/main.dart';
import 'package:historical_camera/strings.dart';

void main() {
  testWidgets('app boots and shows placeholder', (tester) async {
    await tester.pumpWidget(const HistoricalCameraApp());
    expect(find.text(Strings.appName), findsOneWidget);
  });
}
