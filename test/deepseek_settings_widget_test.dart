import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/ai_settings/ai_settings.dart';
import 'package:spark/src/features/ai_settings/application/deepseek_credential_controller.dart';
import 'package:spark/src/features/ai_settings/data/in_memory_deepseek_credential_repository.dart';
import 'package:spark/src/features/ai_settings/presentation/deepseek_settings_section.dart';
import 'package:spark/src/core/theme/theme_controller.dart';
import 'package:spark/src/features/profile/presentation/profile_screen.dart';

void main() {
  testWidgets('profile configures and deletes a DeepSeek API key',
      (tester) async {
    final repository = InMemoryDeepSeekCredentialRepository();
    final controller = DeepSeekCredentialController(
      repository: repository,
      validator: _AcceptingValidator(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(
            themeController: ThemeController(),
            aiSettingsBuilder: (_) =>
                DeepSeekSettingsSection(controller: controller),
          ),
        ),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('profile-deepseek-settings')),
    );
    await tester.tap(find.byKey(const ValueKey('profile-deepseek-settings')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('deepseek-api-key-input')),
      'sk-widget-1234',
    );
    await tester.tap(find.byKey(const ValueKey('save-deepseek-api-key')));
    await tester.pumpAndSettle();

    expect(await repository.readApiKey(), 'sk-widget-1234');
    expect(controller.configured, isTrue);

    await tester.tap(find.byKey(const ValueKey('profile-deepseek-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-deepseek-api-key')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-delete-deepseek-api-key')),
    );
    await tester.pumpAndSettle();

    expect(await repository.readApiKey(), isNull);
    expect(controller.configured, isFalse);
  });
}

class _AcceptingValidator implements DeepSeekCredentialValidator {
  @override
  Future<void> validate(String apiKey) async {}
}
