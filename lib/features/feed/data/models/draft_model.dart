import '../../../camera/data/models/sound_model.dart';

class DraftModel {
  final String id;
  final List<String> videoPaths;
  final String? thumbnailPath;
  final String? caption;
  final DateTime createdAt;
  final Sound? sound;

  DraftModel({
    required this.id,
    required this.videoPaths,
    this.thumbnailPath,
    this.caption,
    required this.createdAt,
    this.sound,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoPaths': videoPaths,
      'thumbnailPath': thumbnailPath,
      'caption': caption,
      'createdAt': createdAt.toIso8601String(),
      'sound': sound?.toJson(),
    };
  }

  factory DraftModel.fromJson(Map<String, dynamic> json) {
    // Handle migration from single path to list
    List<String> paths = [];
    if (json['videoPaths'] != null) {
      paths = List<String>.from(json['videoPaths']);
    } else if (json['videoPath'] != null) {
      paths = [json['videoPath']];
    }

    return DraftModel(
      id: json['id'],
      videoPaths: paths,
      thumbnailPath: json['thumbnailPath'],
      caption: json['caption'],
      createdAt: DateTime.parse(json['createdAt']),
      sound: json['sound'] != null ? Sound.fromJson(json['sound']) : null,
    );
  }
}
