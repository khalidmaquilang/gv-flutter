import 'package:test_flutter/features/camera/data/models/sound_model.dart';

class SoundService {
  Future<List<Sound>> getTrendingSounds() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return _dummySounds;
  }

  Future<List<Sound>> searchSounds(String query) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (query.isEmpty) return _dummySounds;
    return _dummySounds
        .where(
          (s) =>
              s.title.toLowerCase().contains(query.toLowerCase()) ||
              s.author.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  final List<Sound> _dummySounds = [
    Sound(
      id: '1',
      title: 'Simple Melody',
      author: 'AI Composer',
      url: 'assets/sounds/track1.wav',
      coverUrl: 'https://dummyimage.com/100x100/ff00ff/fff&text=Melody',
      duration: 15,
    ),
    Sound(
      id: '2',
      title: 'Fast Beat',
      author: 'AI Drummer',
      url: 'assets/sounds/track2.wav',
      coverUrl: 'https://dummyimage.com/100x100/00ff00/000&text=Beat',
      duration: 5,
    ),
    Sound(
      id: '3',
      title: 'Ambient Chill',
      author: 'AI Synth',
      url: 'assets/sounds/track3.wav',
      coverUrl: 'https://dummyimage.com/100x100/0000ff/fff&text=Chill',
      duration: 60,
    ),
    Sound(
      id: '4',
      title: 'Chord Pad',
      author: 'AI Harmony',
      url: 'assets/sounds/track4.wav',
      coverUrl: 'https://dummyimage.com/100x100/ffff00/000&text=Pad',
      duration: 30,
    ),
    Sound(
      id: '5',
      title: 'Epic Rising',
      author: 'AI FX',
      url: 'assets/sounds/track5.wav',
      coverUrl: 'https://dummyimage.com/100x100/00ffff/000&text=Epic',
      duration: 10,
    ),
  ];
}
