class Sound {
  final String id;
  final String title;
  final String author;
  final String url; // For now this can be asset path or remote URL
  final String coverUrl;
  final int duration; // in seconds

  Sound({
    required this.id,
    required this.title,
    required this.author,
    required this.url,
    required this.coverUrl,
    required this.duration,
  });
}
