import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_camera/ui/era_slider.dart';

void main() {
  testWidgets('paints without throwing when narrower than a label '
      '(seen on device mid-rotation)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 12, // narrower than any anchor label
          child: EraSlider(
            year: 1965,
            nowYear: 2026,
            onChanged: (_) {},
            onChangeEnd: (_) {},
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
