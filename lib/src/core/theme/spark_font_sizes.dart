/// Semantic font-size scale for Spark.
///
/// Single source of truth for text sizing across feature modules. Values are
/// plain doubles so call sites keep their existing `TextStyle` structure and
/// only swap the literal: `fontSize: SparkFontSizes.caption`.
///
/// The scale intentionally carries no weight/height so migrating a call site
/// never changes rendering beyond the ≤1px size rounding from the old
/// fractional literal (9.5/10.5/12.5/...) to the nearest scale step.
abstract final class SparkFontSizes {
  static const tiny = 10.0;
  static const caption = 11.0;
  static const footnote = 12.0;
  static const bodySmall = 13.0;
  static const body = 14.0;
  static const bodyLarge = 15.0;
  static const titleSmall = 16.0;
  static const title = 17.0;
  static const titleLarge = 18.0;
  static const headlineSmall = 20.0;
  static const headline = 22.0;
  static const display = 24.0;
}
