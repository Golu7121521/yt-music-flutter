import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../models/track_model.dart';
import 'youtube_service.dart';

enum PlayerLoadingState { idle, loading, ready, error }

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final YoutubeService _youtubeService = YoutubeService();

  TrackModel? _currentTrack;
  PlayerLoadingState _loadingState = PlayerLoadingState.idle;
  String? _errorMessage;
  bool _isRateLimitError = false;

  TrackModel? get currentTrack => _currentTrack;
  PlayerLoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;
  bool get isRateLimitError => _isRateLimitError;

  AudioPlayer get player => _audioPlayer;

  bool get isPlaying => _audioPlayer.playing;
  Duration get position => _audioPlayer.position;
  Duration get bufferedPosition => _audioPlayer.bufferedPosition;
  Duration get duration => _audioPlayer.duration ?? Duration.zero;

  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration> get bufferedPositionStream =>
      _audioPlayer.bufferedPositionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  AudioPlayerService() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _audioPlayer.playerStateStream.listen((state) {
      notifyListeners();
    });

    _audioPlayer.positionStream.listen((_) {
      notifyListeners();
    });
  }

  Future<void> playTrack(TrackModel track) async {
    _currentTrack = track;
    _loadingState = PlayerLoadingState.loading;
    _errorMessage = null;
    _isRateLimitError = false;
    notifyListeners();

    try {
      final streamUrl = await _youtubeService.getAudioStreamUrl(
        track.videoId,
      );
      _currentTrack = track.copyWith(streamUrl: streamUrl);

      await _audioPlayer.setUrl(streamUrl);

      _loadingState = PlayerLoadingState.ready;
      notifyListeners();
      await _audioPlayer.play();
    } on YoutubeServiceException catch (e) {
      _loadingState = PlayerLoadingState.error;
      _errorMessage = e.message;
      _isRateLimitError = false;
      notifyListeners();
    } catch (e) {
      _loadingState = PlayerLoadingState.error;
      _errorMessage = 'Could not play this track. Please try again.';
      _isRateLimitError = false;
      notifyListeners();
    }
  }

  Future<void> retryCurrentTrack() async {
    final track = _currentTrack;
    if (track == null) return;
    await playTrack(track);
  }

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
    notifyListeners();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    notifyListeners();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
    notifyListeners();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentTrack = null;
    _loadingState = PlayerLoadingState.idle;
    notifyListeners();
  }

  Future<void> seekForward({
    Duration amount = const Duration(seconds: 10),
  }) async {
    final newPosition = _audioPlayer.position + amount;
    final maxDuration = _audioPlayer.duration ?? Duration.zero;
    await _audioPlayer.seek(
      newPosition > maxDuration ? maxDuration : newPosition,
    );
    notifyListeners();
  }

  Future<void> seekBackward({
    Duration amount = const Duration(seconds: 10),
  }) async {
    final newPosition = _audioPlayer.position - amount;
    await _audioPlayer.seek(
      newPosition < Duration.zero ? Duration.zero : newPosition,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _youtubeService.dispose();
    super.dispose();
  }
}
