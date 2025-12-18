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

  final ScrollController _scrollController = ScrollController();
  List<Sound> _sounds = [];
  bool _isLoading = true;
  bool _isMoreLoading = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String _searchQuery = "";
  String? _playingUrl;

  @override
  void initState() {
    super.initState();
    _loadSounds();
    _scrollController.addListener(_onScroll);

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _playingUrl = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isMoreLoading &&
        _hasMore) {
      _loadMoreSounds();
    }
  }

  Future<void> _loadSounds() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
      _sounds = [];
    });

    final sounds = await _soundService.getSounds(
      page: _currentPage,
      query: _searchQuery,
    );

    if (mounted) {
      setState(() {
        _sounds = sounds;
        _isLoading = false;
        if (sounds.isEmpty) _hasMore = false;
      });
    }
  }

  Future<void> _loadMoreSounds() async {
    setState(() {
      _isMoreLoading = true;
    });

    final nextPage = _currentPage + 1;
    final sounds = await _soundService.getSounds(
      page: nextPage,
      query: _searchQuery,
    );

    if (mounted) {
      setState(() {
        if (sounds.isEmpty) {
          _hasMore = false;
        } else {
          _sounds.addAll(sounds);
          _currentPage = nextPage;
        }
        _isMoreLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_searchQuery == query) return;

    // Stop playing music when search changes
    _audioPlayer.stop();

    setState(() {
      _searchQuery = query;
      _playingUrl = null;
    });
    // Debounce could be added here
    _loadSounds();
  }

  Future<void> _togglePreview(Sound sound) async {
    try {
      if (_playingUrl == sound.url) {
        await _audioPlayer.stop();
        setState(() {
          _playingUrl = null;
        });
      } else {
        await _audioPlayer.stop();

        if (sound.url.isNotEmpty) {
          // Verify URL validity
          final uri = Uri.tryParse(sound.url);
          if (uri == null || !uri.hasAbsolutePath) {
            print("Invalid sound URL: ${sound.url}");
            return;
          }

          // Use setSourceUrl + resume for better reliability
          await _audioPlayer.setSourceUrl(sound.url);
          await _audioPlayer.resume();

          setState(() {
            _playingUrl = sound.url;
          });
        }
      }
    } catch (e) {
      print("Error toggling preview for ${sound.title}: $e");
      // Optionally show a snackbar or toast
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to play preview: $e")));
      }
      setState(() {
        _playingUrl = null;
      });
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
                    controller: _scrollController,
                    itemCount: _sounds.length + (_isMoreLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _sounds.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                              color: AppColors.neonPink,
                            ),
                          ),
                        );
                      }
                      final sound = _sounds[index];
                      final isPlaying = _playingUrl == sound.url;

                      return ListTile(
                        leading: GestureDetector(
                          onTap: () => _togglePreview(sound),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[800], // Plain color
                              borderRadius: BorderRadius.circular(4),
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
