import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/theme/spark_design_tokens.dart';
import 'package:spark/src/core/widgets/cherry_motion.dart';

void main() {
  test('Cherry Studio token scale keeps the compact component hierarchy', () {
    expect(SparkDesignTokens.radiusMd, 8);
    expect(SparkDesignTokens.radiusLg, 10);
    expect(SparkDesignTokens.radius3Xl, 22);
    expect(SparkDesignTokens.space1, 4);
  });

  testWidgets(
    'entry animation reaches its final state when animations are disabled',
    (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(body: CherryEntryAnimation(child: Text('论文内容'))),
          ),
        ),
      );

      final transition = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(CherryEntryAnimation),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(transition.opacity.value, 1);
    },
  );
}
