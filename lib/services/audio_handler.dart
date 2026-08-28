import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

OpenAirAudioHandler? _audioHandlerInstance;

OpenAirAudioHandler getAudioHandler() {
  if (_audioHandlerInstance == null) {
    JustAudioMediaKit.ensureInitialized(
      linux: true,
      windows: true,
      android: false,
      iOS: true,
      macOS: true,
    );
    _audioHandlerInstance = OpenAirAudioHandler();
  }
  return _audioHandlerInstance!;
}

class OpenAirAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer player = AudioPlayer();

  OpenAirAudioHandler() {
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenToDurationChanges();
    _listenToCurrentPosition();
    _listenToPlayerStateChanges();
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = player.playing;
      final processingState = player.processingState;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          if (processingState != ProcessingState.completed && playing)
            MediaControl.pause
          else
            MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[processingState]!,
        playing: processingState == ProcessingState.completed ? false : playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: event.currentIndex,
      ));
    });
  }

  void _listenToDurationChanges() {
    player.durationStream.listen((duration) {
      final newQueue = queue.value;
      if (newQueue.isNotEmpty) {
        final oldMediaItem = newQueue[0];
        final newMediaItem = oldMediaItem.copyWith(duration: duration);
        newQueue[0] = newMediaItem;
        queue.add(newQueue);
        mediaItem.add(newMediaItem);
      }
    });
  }

  void _listenToCurrentPosition() {
    player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
  }

  void _listenToPlayerStateChanges() {
    player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        debugPrint('AudioHandler: Playback completed');

        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.completed,
          playing: false,
        ));
      }
    });
  }

  Future<void> setMediaItem({
    required String id,
    required String title,
    required String artist,
    String? album,
    String? artUri,
    Duration? duration,
  }) async {
    final mediaItem = MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      artUri: artUri != null && artUri.isNotEmpty
          ? (artUri.startsWith('http://') || artUri.startsWith('https://')
              ? Uri.parse(artUri)
              : Uri.file(artUri))
          : null,
      duration: duration,
    );
    queue.add([mediaItem]);
    this.mediaItem.add(mediaItem);
  }

  Future<void> updateArtUri(String artUri) async {
    final newQueue = queue.value;
    if (newQueue.isNotEmpty) {
      final oldMediaItem = newQueue[0];
      final newMediaItem = oldMediaItem.copyWith(
        artUri: artUri.isNotEmpty
            ? (artUri.startsWith('http://') || artUri.startsWith('https://')
                ? Uri.parse(artUri)
                : Uri.file(artUri))
            : null,
      );
      newQueue[0] = newMediaItem;
      queue.add(newQueue);
      mediaItem.add(newMediaItem);
    }
  }

  Future<void> playFromUrl(String url, {Duration? initialPosition}) async {
    try {
      await player.setUrl(url,
          initialPosition: initialPosition ?? Duration.zero);
      await player.play();
    } catch (e) {
      debugPrint('Error playing from URL: $e');
    }
  }

  // Media library snapshot used by Android Auto / the media browser. The UI
  // keeps this up to date via [updateMediaLibrary] whenever subscriptions or
  // episodes change.
  List<MediaItem> _podcasts = [];
  final Map<String, List<MediaItem>> _episodesByPodcastId = {};
  final Map<String, MediaItem> _episodesById = {};
  final Map<String, String> _urlsByGuid = {};

  void updateMediaLibrary({
    required List<MediaItem> podcasts,
    required Map<String, List<MediaItem>> episodesByPodcast,
    required Map<String, String> urlsByGuid,
  }) {
    _podcasts = podcasts;
    _episodesByPodcastId
      ..clear()
      ..addAll(episodesByPodcast);
    _episodesById.clear();
    for (final episodes in _episodesByPodcastId.values) {
      for (final episode in episodes) {
        _episodesById[episode.id] = episode;
      }
    }
    _urlsByGuid
      ..clear()
      ..addAll(urlsByGuid);
  }

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
      [Map<String, dynamic>? options]) async {
    if (parentMediaId.isEmpty || parentMediaId == 'root') {
      return _podcasts;
    }
    return _episodesByPodcastId[parentMediaId] ?? [];
  }

  @override
  Future<List<MediaItem>> search(String query,
      [Map<String, dynamic>? extras]) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final matches = _episodesById.values
        .where((item) =>
            item.title.toLowerCase().contains(q) ||
            (item.artist?.toLowerCase().contains(q) ?? false) ||
            (item.album?.toLowerCase().contains(q) ?? false))
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return matches.take(50).toList();
  }

  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {
    final episodes = _episodesByPodcastId[mediaId];
    if (episodes != null && episodes.isNotEmpty) {
      await _playFromLibraryItem(episodes.first);
      return;
    }

    final episode = _episodesById[mediaId];
    if (episode != null) {
      await _playFromLibraryItem(episode);
    }
  }

  @override
  Future<void> playFromSearch(String query,
      [Map<String, dynamic>? extras]) async {
    final results = await search(query, extras);
    if (results.isNotEmpty) {
      await _playFromLibraryItem(results.first);
    }
  }

  Future<void> _playFromLibraryItem(MediaItem episode) async {
    final url = _urlsByGuid[episode.id];
    if (url == null || url.isEmpty) {
      debugPrint('AudioHandler: No URL known for ${episode.id}');
      return;
    }
    await setMediaItem(
      id: episode.id,
      title: episode.title,
      artist: episode.artist ?? '',
      album: episode.album,
      artUri: episode.artUri?.toString(),
      duration: episode.duration,
    );
    await playFromUrl(url);
  }

  Future<void> playFromFile(String filePath,
      {Duration? initialPosition}) async {
    try {
      await player.setFilePath(filePath,
          initialPosition: initialPosition ?? Duration.zero);
      await player.play();
    } catch (e) {
      debugPrint('Error playing from file: $e');
    }
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> setSpeed(double speed) => player.setSpeed(speed);

  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  @override
  Future<void> skipToNext() async {
    final callback = onSkipToNext;
    if (callback != null) {
      await callback();
      return;
    }
    await super.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    final callback = onSkipToPrevious;
    if (callback != null) {
      await callback();
      return;
    }
    await super.skipToPrevious();
  }

  @override
  Future<void> fastForward() async {
    final newPosition = player.position + const Duration(seconds: 15);
    if (newPosition < (player.duration ?? Duration.zero)) {
      await player.seek(newPosition);
    }
  }

  @override
  Future<void> rewind() async {
    final newPosition = player.position - const Duration(seconds: 15);
    if (newPosition > Duration.zero) {
      await player.seek(newPosition);
    } else {
      await player.seek(Duration.zero);
    }
  }

  Duration get position => player.position;
  Duration? get duration => player.duration;
  Stream<PlayerState> get playerStateStream => player.playerStateStream;
  Stream<Duration> get positionStream => player.positionStream;
  Stream<Duration?> get durationStream => player.durationStream;

  Future<void> dispose() async {
    await player.dispose();
  }
}
