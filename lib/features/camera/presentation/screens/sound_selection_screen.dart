import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import '../../data/models/sound_model.dart';
import '../../data/services/sound_service.dart';

class SoundSelectionScreen extends StatefulWidget {
  const SoundSelectionScreen({super.key});

  @override
  State<SoundSelectionScreen> createState() => _SoundSelectionScreenState();
}

class _SoundSelectionScreenState extends State<SoundSelectionScreen> {
  final SoundService _soundService = SoundService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Sound> _sounds = [];
  bool _isLoading = true;
  String _searchQuery = "";
  String? _playingSoundId;

  @override
  void initState() {
    super.initState();
    _loadSounds();

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _playingSoundId = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSounds() async {
    setState(() {
      _isLoading = true;
    });

    final sounds = await _soundService.searchSounds(_searchQuery);

    if (mounted) {
      setState(() {
        _sounds = sounds;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    // Debounce could be added here
    _loadSounds();
  }

  Future<void> _togglePreview(Sound sound) async {
    if (_playingSoundId == sound.id) {
      await _audioPlayer.stop();
      setState(() {
        _playingSoundId = null;
      });
    } else {
      await _audioPlayer.stop();
      // For dummy assets, ensure they are in pubspec or handle error
      // Assuming assets for now based on service
      if (sound.url.isNotEmpty) {
        // If it's an asset
        if (sound.url.startsWith('assets/')) {
          // Remove 'assets/' prefix if AudioPlayer default needs it,
          // typically AssetSource takes path relative to assets or full depending on config.
          // AudioPlayer AssetSource needs prefix removed? No, usually "sounds/beep.wav" if in assets/sounds
          // Let's assume the service returns full path "assets/sounds/..."
          // AssetSource expects path inside asset bundle.
          String assetPath = sound.url;
          if (assetPath.startsWith('assets/')) {
            assetPath = assetPath.substring(7); // remove 'assets/'
          }
          await _audioPlayer.play(AssetSource(assetPath));
        } else {
          await _audioPlayer.play(UrlSource(sound.url));
        }

        setState(() {
          _playingSoundId = sound.id;
        });
      }
    }
  }

  void _selectSound(Sound sound) {
    Navigator.of(context).pop(sound);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Add Sound",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search sounds...",
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.neonPink),
                  )
                : _sounds.isEmpty
                ? const Center(
                    child: Text(
                      "No sounds found",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _sounds.length,
                    itemBuilder: (context, index) {
                      final sound = _sounds[index];
                      final isPlaying = _playingSoundId == sound.id;

                      return ListTile(
                        leading: GestureDetector(
                          onTap: () => _togglePreview(sound),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              image: DecorationImage(
                                image: NetworkImage(sound.coverUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          sound.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          "${sound.author} • ${sound.duration}s",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _selectSound(sound),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.neonPink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            minimumSize: const Size(60, 30),
                          ),
                          child: const Icon(Icons.check, size: 16),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
