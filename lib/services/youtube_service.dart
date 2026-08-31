import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track_model.dart';

class YoutubeService {
  static const List<String> _pipedInstances = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.tokhmi.xyz',
    'https://api.piped.projectsegfau.lt',
    'https://piped-api.privacy.com.de',
    'https://pipedapi.leptons.xyz',
  ];

  static const Duration _requestTimeout = Duration(seconds: 15);

  final http.Client _client = http.Client();

  Future<List<TrackModel>> searchVideos(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final encodedQuery = Uri.encodeQueryComponent(query);
    Object? lastError;

    for (final baseUrl in _pipedInstances) {
      try {
        final uri = Uri.parse(
          '$baseUrl/search?q=$encodedQuery&filter=music_songs',
        );

        final response = await _client
            .get(uri, headers: _defaultHeaders())
            .timeout(_requestTimeout);

        if (response.statusCode != 200) {
          throw YoutubeServiceException(
            'Search request failed with status ${response.statusCode}.',
          );
        }

        final decoded = jsonDecode(response.body);
        final List<dynamic> items = decoded is Map<String, dynamic>
            ? (decoded['items'] as List<dynamic>? ?? [])
            : (decoded is List<dynamic> ? decoded : []);

        final List<TrackModel> tracks = [];

        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;

          final String? url = item['url'] as String?;
          if (url == null || !url.contains('watch?v=')) {
            continue;
          }

          final videoId = Uri.parse(url).queryParameters['v'];
          if (videoId == null || videoId.isEmpty) {
            continue;
          }

          final title = (item['title'] as String?)?.trim();
          if (title == null || title.isEmpty) {
            continue;
          }

          final author = (item['uploaderName'] as String?)?.trim() ??
              'Unknown Artist';

          final thumbnailUrl = (item['thumbnail'] as String?) ?? '';

          final durationSeconds = item['duration'];
          final duration = durationSeconds is int && durationSeconds > 0
              ? Duration(seconds: durationSeconds)
              : Duration.zero;

          tracks.add(
            TrackModel(
              videoId: videoId,
              title: title,
              author: author,
              thumbnailUrl: thumbnailUrl,
              duration: duration,
            ),
          );
        }

        return tracks;
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    throw YoutubeServiceException(
      'Failed to search videos on all available Piped instances: '
      '${_cleanErrorMessage(lastError)}',
    );
  }

  Future<String> getAudioStreamUrl(String videoId) async {
    Object? lastError;

    for (final baseUrl in _pipedInstances) {
      try {
        final uri = Uri.parse('$baseUrl/streams/$videoId');

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
            'Unexpected response format from Piped instance.',
          );
        }

        final List<dynamic> audioStreams =
            decoded['audioStreams'] as List<dynamic>? ?? [];

        if (audioStreams.isEmpty) {
          throw YoutubeServiceException(
            'No audio-only streams available for this video.',
          );
        }

        final m4aStreams = audioStreams.where((s) {
          if (s is! Map<String, dynamic>) return false;
          final format = (s['format'] as String?)?.toLowerCase() ?? '';
          final mimeType = (s['mimeType'] as String?)?.toLowerCase() ?? '';
          return format.contains('m4a') || mimeType.contains('mp4a');
        }).toList();

        final candidateStreams =
            m4aStreams.isNotEmpty ? m4aStreams : audioStreams;

        Map<String, dynamic>? bestStream;
        int bestBitrate = -1;

        for (final stream in candidateStreams) {
          if (stream is! Map<String, dynamic>) continue;
          final bitrate = _parseBitrate(stream['bitrate']);
          if (bitrate > bestBitrate) {
            bestBitrate = bitrate;
            bestStream = stream;
          }
        }

        bestStream ??= candidateStreams.first as Map<String, dynamic>;

        final streamUrl = bestStream['url'] as String?;
        if (streamUrl == null || streamUrl.isEmpty) {
          throw YoutubeServiceException(
            'Selected audio stream has no playable URL.',
          );
        }

        return streamUrl;
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    throw YoutubeServiceException(
      'Failed to extract audio stream on all available Piped instances: '
      '${_cleanErrorMessage(lastError)}',
    );
  }

  Future<TrackModel> getVideoDetails(String videoId) async {
    Object? lastError;

    for (final baseUrl in _pipedInstances) {
      try {
        final uri = Uri.parse('$baseUrl/streams/$videoId');

        final response = await _client
            .get(uri, headers: _defaultHeaders())
            .timeout(_requestTimeout);

        if (response.statusCode != 200) {
          throw YoutubeServiceException(
            'Video details request failed with status ${response.statusCode}.',
          );
        }

        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw YoutubeServiceException(
            'Unexpected response format from Piped instance.',
          );
        }

        final title = (decoded['title'] as String?)?.trim() ?? 'Unknown Title';
        final author =
            (decoded['uploader'] as String?)?.trim() ?? 'Unknown Artist';
        final thumbnailUrl = (decoded['thumbnailUrl'] as String?) ?? '';
        final durationSeconds = decoded['duration'];
        final duration = durationSeconds is int && durationSeconds > 0
            ? Duration(seconds: durationSeconds)
            : Duration.zero;

        return TrackModel(
          videoId: videoId,
          title: title,
          author: author,
          thumbnailUrl: thumbnailUrl,
          duration: duration,
        );
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    throw YoutubeServiceException(
      'Failed to fetch video details on all available Piped instances: '
      '${_cleanErrorMessage(lastError)}',
    );
  }

  int _parseBitrate(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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
