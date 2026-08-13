Uri? validExternalHttpUri(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}
