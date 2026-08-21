import '../../../core/diagnostics/runtime_diagnostics.dart';
import '../domain/side_chat_dismiss_preference.dart';

/// side chat「不再显示」偏好的应用层访问入口。
///
/// presentation 只依赖本服务与 [SideChatDismissPreference] 抽象；
/// 读写失败经 [SparkDiagnostics] 上报（warning 级）并按默认值降级，
/// 不阻断返回主聊天的交互。
class SideChatDismissPreferenceController {
  SideChatDismissPreferenceController({
    required SideChatDismissPreference preference,
  }) : _preference = preference;

  final SideChatDismissPreference _preference;

  /// 读取「不再显示」偏好；失败时按未抑制（false）降级。
  Future<bool> load() async {
    try {
      return await _preference.load();
    } catch (error, stackTrace) {
      SparkDiagnostics.reportUnexpected(
        operation: SparkDiagnosticOperation.chatSideChatPreferenceLoad,
        error: error,
        stackTrace: stackTrace,
        severity: SparkDiagnosticSeverity.warning,
      );
      return false;
    }
  }

  /// 保存「不再显示」偏好；失败时静默降级（不阻断返回）。
  Future<void> save(bool suppress) async {
    try {
      await _preference.save(suppress);
    } catch (error, stackTrace) {
      SparkDiagnostics.reportUnexpected(
        operation: SparkDiagnosticOperation.chatSideChatPreferenceSave,
        error: error,
        stackTrace: stackTrace,
        severity: SparkDiagnosticSeverity.warning,
      );
    }
  }
}
