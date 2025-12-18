class Sound {
  final int
  id; // Changed to int as typically API IDs are ints, but could be String. User said "we need id".
  final String title;
  final String author;
  final String url;
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'path': url, // API uses 'path'
      'coverUrl': coverUrl,
      'duration': duration,
    };
  }

  factory Sound.fromJson(Map<String, dynamic> json) {
    int parsedDuration = 0;
    if (json['duration_formatted'] != null) {
      final parts = json['duration_formatted'].toString().split(':');
      if (parts.length == 2) {
        parsedDuration = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      } else if (parts.length == 3) {
        parsedDuration =
            int.parse(parts[0]) * 3600 +
            int.parse(parts[1]) * 60 +
            int.parse(parts[2]);
      }
    }

    return Sound(
      id: json['id'] ?? 0, // Default to 0 if missing, need to handle carefully
      title: json['name'] ?? 'Unknown Title',
      author: json['artist'] ?? 'Unknown Artist',
      url: json['path'] ?? '',
      coverUrl:
          json['cover_url'] ??
          'https://www.shutterstock.com/image-vector/music-note-icon-vector-illustration-600nw-2253322131.jpg', // Default image
      duration: parsedDuration,
    );
  }
}
