import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_player_service.dart';

class BottomPlayer extends StatelessWidget {
  const BottomPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, playerService, child) {
        final track = playerService.currentTrack;

        if (track == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => _showFullPlayer(context, playerService),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<Duration>(
                  stream: playerService.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final total = playerService.duration;
                    final progress = total.inMilliseconds > 0
                        ? position.inMilliseconds / total.inMilliseconds
                        : 0.0;
                    return LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 2,
                      backgroundColor: Colors.grey.shade300,
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: track.thumbnailUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            width: 44,
                            height: 44,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.music_note),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              track.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (playerService.loadingState ==
                          PlayerLoadingState.loading)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        StreamBuilder<PlayerState>(
                          stream: playerService.playerStateStream,
                          builder: (context, snapshot) {
                            final playing = snapshot.data?.playing ?? false;
                            return IconButton(
                              icon: Icon(
                                playing
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                size: 36,
                              ),
                              onPressed: () => playerService.togglePlayPause(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFullPlayer(BuildContext context, AudioPlayerService service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FullPlayerSheet(playerService: service),
    );
  }
}

class FullPlayerSheet extends StatelessWidget {
  final AudioPlayerService playerService;

  const FullPlayerSheet({super.key, required this.playerService});

  @override
  Widget build(BuildContext context) {
    final track = playerService.currentTrack;
    if (track == null) return const SizedBox.shrink();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: track.thumbnailUrl,
              width: 260,
              height: 195,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                width: 260,
                height: 195,
                color: Colors.grey.shade300,
                child: const Icon(Icons.music_note, size: 48),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              track.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            track.author,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: StreamBuilder<Duration>(
              stream: playerService.positionStream,
              builder: (context, posSnapshot) {
                return StreamBuilder<Duration>(
                  stream: playerService.bufferedPositionStream,
                  builder: (context, bufSnapshot) {
                    return StreamBuilder<Duration?>(
                      stream: playerService.durationStream,
                      builder: (context, durSnapshot) {
                        final position = posSnapshot.data ?? Duration.zero;
                        final buffered = bufSnapshot.data ?? Duration.zero;
                        final total = durSnapshot.data ?? Duration.zero;
                        return ProgressBar(
                          progress: position,
                          buffered: buffered,
                          total: total,
                          onSeek: (duration) {
                            playerService.seek(duration);
                          },
                          baseBarColor: Colors.grey.shade300,
                          progressBarColor:
                              Theme.of(context).colorScheme.primary,
                          bufferedBarColor: Colors.grey.shade400,
                          thumbColor: Theme.of(context).colorScheme.primary,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.replay_10),
                onPressed: () => playerService.seekBackward(),
              ),
              const SizedBox(width: 16),
              StreamBuilder<PlayerState>(
                stream: playerService.playerStateStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing ?? false;
                  final processingState = snapshot.data?.processingState;
                  if (processingState == ProcessingState.loading ||
                      processingState == ProcessingState.buffering) {
                    return const SizedBox(
                      width: 64,
                      height: 64,
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  return IconButton(
                    iconSize: 64,
                    icon: Icon(
                      playing
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                    ),
                    onPressed: () => playerService.togglePlayPause(),
                  );
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.forward_10),
                onPressed: () => playerService.seekForward(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (playerService.loadingState == PlayerLoadingState.error)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                playerService.errorMessage ?? 'An error occurred',
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
