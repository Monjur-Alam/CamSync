/// Sizes the way the upload manager prints them: `88 MB`, `2.1 MB`, `1.2 GB`.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) {
    return '${(bytes / gb).toStringAsFixed(1)} GB';
  }
  final asMb = bytes / mb;
  if (asMb >= 100) return '${asMb.toStringAsFixed(0)} MB';
  if (asMb >= 10) {
    final rounded = asMb.toStringAsFixed(1);
    return rounded.endsWith('.0')
        ? '${asMb.toStringAsFixed(0)} MB'
        : '$rounded MB';
  }
  if (asMb >= 1) {
    final rounded = asMb.toStringAsFixed(1);
    return rounded.endsWith('.0')
        ? '${asMb.toStringAsFixed(0)} MB'
        : '$rounded MB';
  }
  final kb = bytes / 1024;
  if (kb >= 1) return '${kb.toStringAsFixed(1)} KB';
  return '$bytes B';
}
