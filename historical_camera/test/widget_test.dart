import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:historical_camera/main.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('boots to spinner, then shows the preview texture',
      (tester) async {
    final api = FakeNativeCameraApi();
    final permissions = FakePermissionService(granted: true);
    await tester.pumpWidget(buildTestScope(
      api: api,
      permissions: permissions,
      child: const HistoricalCameraApp(),
    ));

    // Before initialize completes: black background + boot spinner.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(Texture), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
