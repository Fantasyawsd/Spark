import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/features/local_data/data/in_memory_local_data_repository.dart';
import 'package:spark/src/features/local_data/presentation/local_data_sheet.dart';
import 'package:spark/src/features/profile/presentation/profile_screen.dart';

void main() {
  testWidgets('profile opens local data management and clears chats',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = LocalDataController(
      repository: InMemoryLocalDataRepository(
        const LocalDataUsage(
          paperCacheBytes: 1024,
          chatBytes: 2048,
          businessDataBytes: 4096,
        ),
      ),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ProfileScreen(
              themeController: ThemeController(),
              localDataListenable: controller,
              localDataDescriptionBuilder: () =>
                  '占用 ${formatLocalDataBytes(controller.usage.totalBytes)}',
              onOpenLocalData: () => showLocalDataSheet(
                context,
                controller: controller,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-local-data')),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('profile-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const ValueKey('profile-local-data')));
    await tester.pumpAndSettle();

    expect(find.text('7.0 KB'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('local-data-clear-chats')),
    );
    await tester.pumpAndSettle();
    expect(find.text('清除 ChatPaper 对话？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('local-data-confirm')));
    await tester.pumpAndSettle();

    expect(controller.usage.chatBytes, 0);
    expect(find.text('5.0 KB'), findsOneWidget);
    expect(find.text('ChatPaper 对话已清除'), findsOneWidget);
  });
}
