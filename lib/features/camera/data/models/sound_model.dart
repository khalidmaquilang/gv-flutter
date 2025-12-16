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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'url': url,
      'coverUrl': coverUrl,
      'duration': duration,
    };
  }

  factory Sound.fromJson(Map<String, dynamic> json) {
    return Sound(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      url: json['url'],
      coverUrl: json['coverUrl'],
      duration: json['duration'],
    );
  }
}
