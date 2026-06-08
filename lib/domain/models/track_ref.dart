class TrackRef {
  const TrackRef({
    required this.id,
    required this.localPath,
    required this.displayName,
    required this.durationMs,
    this.mimeType,
  });

  final String id;
  final String localPath;
  final String displayName;
  final int durationMs;
  final String? mimeType;
}
