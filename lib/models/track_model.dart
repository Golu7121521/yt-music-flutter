class TrackModel {
  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final Duration duration;
  String? streamUrl;

  TrackModel({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.duration,
    this.streamUrl,
  });

  TrackModel copyWith({
    String? videoId,
    String? title,
    String? author,
    String? thumbnailUrl,
    Duration? duration,
    String? streamUrl,
  }) {
    return TrackModel(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      author: author ?? this.author,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      streamUrl: streamUrl ?? this.streamUrl,
    );
  }

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final minutesStr = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutesStr:$secondsStr';
    }
    return '$minutesStr:$secondsStr';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrackModel && other.videoId == videoId;
  }

  @override
  int get hashCode => videoId.hashCode;

  @override
  String toString() {
    return 'TrackModel(videoId: $videoId, title: $title, author: $author)';
  }
}
