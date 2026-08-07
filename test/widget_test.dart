import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';

void main() {
  testWidgets('motion tokens honor the system reduce-motion setting',
      (tester) async {
    Duration? resolvedDuration;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              resolvedDuration = MotionTokens.duration(
                context,
                MotionTokens.pageDuration,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(resolvedDuration, Duration.zero);
  });

  testWidgets('startup shows the Spark logo before opening the feed',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SparkApp());

    expect(
      find.byKey(const ValueKey('spark-splash')),
      findsOneWidget,
    );
    final logo = tester.widget<Image>(find.byType(Image));
    expect(
      (logo.image as AssetImage).assetName,
      'assets/images/spark_logo.png',
    );

    await tester.pump(
      MotionTokens.splashDuration + const Duration(milliseconds: 1),
    );
    expect(
      find.byKey(const ValueKey('spark-splash')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('paper-feed')), findsOneWidget);
  });

  testWidgets('startup skips its animation when reduced motion is enabled',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(const SparkApp());

    expect(
      find.byKey(const ValueKey('spark-splash')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('paper-feed')), findsOneWidget);
  });

  testWidgets('shell exposes only papers, AI chat and profile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SparkApp(showSplash: false));
    await tester.pump();

    expect(find.byKey(const ValueKey('bottom-nav-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-nav-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-nav-2')), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('社区'), findsNothing);
    expect(find.text('私信'), findsNothing);
    expect(find.text('通知'), findsNothing);
    expect(find.byKey(const ValueKey('create-button')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pumpAndSettle();
    expect(find.text(AppVersion.current.display), findsOneWidget);
  });

  testWidgets('community navigation is available only when its flag is on',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const SparkApp(
        showSplash: false,
        config: AppConfig(
          environment: AppEnvironment.development,
          features: FeatureFlags(experimentalCommunity: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('bottom-nav-3')), findsOneWidget);
    expect(find.text('社区'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-feed-1')), findsOneWidget);
  });
}
