import 'package:test_flutter/core/constants/api_constants.dart';
import 'package:test_flutter/core/network/api_client.dart';
import 'package:test_flutter/features/camera/data/models/sound_model.dart';

class SoundService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Sound>> getSounds({int page = 1, String? query}) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.musics,
        queryParameters: {
          'page': page,
          if (query != null && query.isNotEmpty) 'title': query,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        final musicList = data['data'] as List;
        return musicList.map((e) => Sound.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      // Handle error or return empty
      print("Error fetching sounds: $e");
      return [];
    }
  }

  // Deprecated/Modified searchSounds to use the new getSounds
  Future<List<Sound>> searchSounds(String query) async {
    return getSounds(query: query);
  }
}
