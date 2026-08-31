import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track_model.dart';

class YoutubeService {
  // Aapka naya Render server URL
  static const String _baseUrl = 'https://jiosaavn-api-dnva.onrender.com/api';
  
  // Timeout 30 seconds kar diya taaki free server on hone ka time mil sake
  static const Duration _requestTimeout = Duration(seconds: 30);

  final http.Client _client = http.Client();

  Future<List<TrackModel>> searchVideos(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final encodedQuery = Uri.encodeQueryComponent(query);
    final uri = Uri.parse('$_baseUrl/search/songs?query=$encodedQuery');

    try {
      final response = await _client
          .get(uri, headers: _defaultHeaders())
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        throw YoutubeServiceException(
          'Search request failed with status ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw YoutubeServiceException(
          'Unexpected response format from JioSaavn API.',
        );
      }

      if (decoded['success'] != true) {
        throw YoutubeServiceException(
          'JioSaavn API reported an unsuccessful search response.',
        );
      }

      final data = decoded['data'] as Map<String, dynamic>?;
      final List<dynamic> items =
          (data?['results'] as List<dynamic>?) ?? [];

      final List<TrackModel> tracks = [];

      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;

        final track = _parseSongItem(item);
        if (track != null) {
          tracks.add(track);
        }
      }

      return tracks;
    } on TimeoutException {
      throw YoutubeServiceException(
        'The search request timed out. Please check your connection and try again.',
      );
    } on YoutubeServiceException {
      rethrow;
    } catch (e) {
      throw YoutubeServiceException(
        'Failed to search songs: ${_cleanErrorMessage(e)}',
      );
    }
  }

  Future<String> getAudioStreamUrl(String songId) async {
    final uri = Uri.parse('$_baseUrl/songs/$songId');

    try {
      final response = await _client
          .get(uri, headers: _defaultHeaders())
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        throw YoutubeServiceException(
          'Stream request failed with status ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw YoutubeServiceException(
          'Unexpected response format from JioSaavn API.',
        );
      }

      if (decoded['success'] != true) {
        throw YoutubeServiceException(
          'JioSaavn API reported an unsuccessful song lookup.',
        );
      }

      final data = decoded['data'] as List<dynamic>?;
      if (data == null || data.isEmpty) {
        throw YoutubeServiceException(
          'No song data returned for this track.',
        );
      }

      final songItem = data.first as Map<String, dynamic>;
      final downloadUrls = songItem['downloadUrl'] as List<dynamic>?;

      final streamUrl = _pickBestDownloadUrl(downloadUrls);
      if (streamUrl == null) {
        throw YoutubeServiceException(
          'No playable audio stream available for this track.',
        );
      }

      return streamUrl;
    } on TimeoutException {
      throw YoutubeServiceException(
        'The stream request timed out. Please check your connection and try again.',
      );
    } on YoutubeServiceException {
      rethrow;
    } catch (e) {
      throw YoutubeServiceException(
        'Failed to extract audio stream: ${_cleanErrorMessage(e)}',
      );
    }
  }

  Future<TrackModel> getVideoDetails(String songId) async {
    final uri = Uri.parse('$_baseUrl/songs/$songId');

    try {
      final response = await _client
          .get(uri, headers: _defaultHeaders())
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        throw YoutubeServiceException(
          'Song details request failed with status ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw YoutubeServiceException(
          'Unexpected response format from JioSaavn API.',
        );
      }

      if (decoded['success'] != true) {
        throw YoutubeServiceException(
          'JioSaavn API reported an unsuccessful song lookup.',
        );
      }

      final data = decoded['data'] as List<dynamic>?;
      if (data == null || data.isEmpty) {
        throw YoutubeServiceException(
          'No song data returned for this track.',
        );
      }

      final songItem = data.first as Map<String, dynamic>;
      final track = _parseSongItem(songItem);

      if (track == null) {
        throw YoutubeServiceException(
          'Song data could not be parsed into a track.',
        );
      }

      return track;
    } on TimeoutException {
      throw YoutubeServiceException(
        'The song details request timed out. Please check your connection and try again.',
      );
    } on YoutubeServiceException {
      rethrow;
    } catch (e) {
      throw YoutubeServiceException(
        'Failed to fetch song details: ${_cleanErrorMessage(e)}',
      );
    }
  }

  TrackModel? _parseSongItem(Map<String, dynamic> item) {
    final String? songId = item['id'] as String?;
    if (songId == null || songId.isEmpty) {
      return null;
    }

    final title = (item['name'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      return null;
    }

    final author = _extractPrimaryArtist(item);
    final thumbnailUrl = _pickBestImageUrl(item['image'] as List<dynamic>?);

    final durationSeconds = item['duration'];
    final duration = _parseDurationSeconds(durationSeconds);

    return TrackModel(
      videoId: songId,
      title: title,
      author: author,
      thumbnailUrl: thumbnailUrl ?? '',
      duration: duration,
    );
  }

  String _extractPrimaryArtist(Map<String, dynamic> item) {
    try {
      final artists = item['artists'] as Map<String, dynamic>?;
      final primary = artists?['primary'] as List<dynamic>?;

      if (primary != null && primary.isNotEmpty) {
        final firstArtist = primary.first;
        if (firstArtist is Map<String, dynamic>) {
          final name = (firstArtist['name'] as String?)?.trim();
          if (name != null && name.isNotEmpty) {
            return name;
          }
        }
      }
    } catch (_) {
      // Fall through to default below.
    }

    return 'Unknown Artist';
  }

  String? _pickBestImageUrl(List<dynamic>? images) {
    if (images == null || images.isEmpty) {
      return null;
    }

    Map<String, dynamic>? best;
    int bestScore = -1;

    for (final image in images) {
      if (image is! Map<String, dynamic>) continue;

      final quality = (image['quality'] as String?) ?? '';
      final score = _qualityToScore(quality);

      if (score > bestScore) {
        bestScore = score;
        best = image;
      }
    }

    best ??= images.last as Map<String, dynamic>?;
    return best?['url'] as String?;
  }

  int _qualityToScore(String quality) {
    final normalized = quality.toLowerCase().replaceAll('x', '');
    final match = RegExp(r'(\d+)').firstMatch(normalized);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  String? _pickBestDownloadUrl(List<dynamic>? downloadUrls) {
    if (downloadUrls == null || downloadUrls.isEmpty) {
      return null;
    }

    Map<String, dynamic>? best;
    int bestBitrate = -1;

    for (final entry in downloadUrls) {
      if (entry is! Map<String, dynamic>) continue;

      final quality = (entry['quality'] as String?) ?? '';
      final bitrate = _parseKbps(quality);

      if (bitrate > bestBitrate) {
        bestBitrate = bitrate;
        best = entry;
      }
    }

    best ??= downloadUrls.last as Map<String, dynamic>?;
    final url = best?['url'] as String?;
    return (url != null && url.isNotEmpty) ? url : null;
  }

  int _parseKbps(String quality) {
    final match = RegExp(r'(\d+)').firstMatch(quality);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  Duration _parseDurationSeconds(dynamic value) {
    if (value is int && value > 0) {
      return Duration(seconds: value);
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 0) {
        return Duration(seconds: parsed);
      }
    }
    return Duration.zero;
  }

  Map<String, String> _defaultHeaders() {
    return {
      'Accept': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
    };
  }

  String _cleanErrorMessage(Object? error) {
    if (error == null) return 'Unknown error.';
    final message = error.toString();
    if (message.length > 200) {
      return '${message.substring(0, 200)}...';
    }
    return message;
  }

  void dispose() {
    _client.close();
  }
}

class YoutubeServiceException implements Exception {
  final String message;

  YoutubeServiceException(this.message);

  @override
  String toString() => message;
}
