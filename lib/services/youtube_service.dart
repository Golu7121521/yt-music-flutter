import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track_model.dart';

class YoutubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<List<TrackModel>> searchVideos(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final searchResults = await _yt.search.search(query);
      final List<TrackModel> tracks = [];

      for (final result in searchResults) {
        if (result is Video) {
          tracks.add(
            TrackModel(
              videoId: result.id.value,
              title: result.title,
              author: result.author,
              thumbnailUrl: result.thumbnails.highResUrl,
              duration: result.duration ?? Duration.zero,
            ),
          );
        }
      }

      return tracks;
    } catch (e) {
      throw YoutubeServiceException('Failed to search videos: $e');
    }
  }

  Future<String> getAudioStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        VideoId(videoId),
      );

      final audioStreams = manifest.audioOnly;

      if (audioStreams.isEmpty) {
        throw YoutubeServiceException(
          'No audio-only streams available for this video.',
        );
      }

      final bestAudio = audioStreams.withHighestBitrate();
      return bestAudio.url.toString();
    } catch (e) {
      throw YoutubeServiceException('Failed to extract audio stream: $e');
    }
  }

  Future<TrackModel> getVideoDetails(String videoId) async {
    try {
      final video = await _yt.videos.get(VideoId(videoId));
      return TrackModel(
        videoId: video.id.value,
        title: video.title,
        author: video.author,
        thumbnailUrl: video.thumbnails.highResUrl,
        duration: video.duration ?? Duration.zero,
      );
    } catch (e) {
      throw YoutubeServiceException('Failed to fetch video details: $e');
    }
  }

  void dispose() {
    _yt.close();
  }
}

class YoutubeServiceException implements Exception {
  final String message;
  YoutubeServiceException(this.message);

  @override
  String toString() => 'YoutubeServiceException: $message';
}
