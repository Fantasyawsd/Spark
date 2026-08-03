/// Extracts a normalized arXiv identifier from user input, or returns null
/// when the input is a keyword query rather than an identifier.
///
/// Accepts modern IDs (`2306.12345`), old-style IDs (`cs.CL/0112017`,
/// `hep-th/9901001`), the `arXiv:` prefix, `abs/`/`pdf/` URLs and a trailing
/// version (`2401.00001v7`). A bare keyword such as "LoRA" is not an ID.
String? extractArxivId(String input) {
  var value = input.trim();
  value = value.replaceFirst(
    RegExp(r'^arXiv:', caseSensitive: false),
    '',
  );
  value = value.replaceFirst(
    RegExp(r'^https?://(?:export\.)?arxiv\.org/(?:abs|pdf)/',
        caseSensitive: false),
    '',
  );
  value = value.replaceFirst(
    RegExp(r'\.pdf$', caseSensitive: false),
    '',
  );
  value = value.replaceFirst(
    RegExp(r'v\d+$', caseSensitive: false),
    '',
  );
  if (!RegExp(r'^\d{4}\.\d{4,5}$').hasMatch(value) &&
      !RegExp(r'^[a-z\-]+(\.[A-Z]{2})?/\d{7}$').hasMatch(value)) {
    return null;
  }
  return value;
}
