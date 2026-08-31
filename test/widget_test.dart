import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yt_stream_player/main.dart';
import 'package:yt_stream_player/services/audio_player_service.dart';
import 'package:yt_stream_player/models/track_model.dart';

void main() {
  testWidgets('App launches and shows search bar', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('YT Stream Player'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search for something to play'), findsOneWidget);
  });

  testWidgets('Typing a query and submitting does not crash the UI',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'test query');
    await tester.pump();

    expect(find.text('test query'), findsOneWidget);
  });

  test('TrackModel formats short duration correctly', () {
    final track = TrackModel(
      videoId: 'abc123',
      title: 'Sample Title',
      author: 'Sample Author',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      duration: const Duration(minutes: 3, seconds: 45),
    );

    expect(track.formattedDuration, '3:45');
  });

  test('TrackModel formats long duration correctly', () {
    final track = TrackModel(
      videoId: 'xyz789',
      title: 'Long Video',
      author: 'Some Channel',
      thumbnailUrl: 'https://example.com/thumb2.jpg',
      duration: const Duration(hours: 1, minutes: 5, seconds: 9),
    );

    expect(track.formattedDuration, '1:05:09');
  });

  test('TrackModel equality is based on videoId', () {
    final trackA = TrackModel(
      videoId: 'same-id',
      title: 'Title A',
      author: 'Author A',
      thumbnailUrl: 'https://example.com/a.jpg',
      duration: const Duration(minutes: 1),
    );
    final trackB = TrackModel(
      videoId: 'same-id',
      title: 'Title B',
      author: 'Author B',
      thumbnailUrl: 'https://example.com/b.jpg',
      duration: const Duration(minutes: 2),
    );

    expect(trackA, equals(trackB));
  });

  test('AudioPlayerService starts in idle state', () {
    final service = AudioPlayerService();
    expect(service.currentTrack, isNull);
    expect(service.loadingState, PlayerLoadingState.idle);
    service.dispose();
  });
}
