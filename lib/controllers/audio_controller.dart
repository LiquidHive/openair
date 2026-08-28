import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:just_audio/just_audio.dart';
import 'package:openair/config/config.dart';
import 'package:openair/model/hive_models/download_model.dart';
import 'package:openair/model/hive_models/feed_model.dart';
import 'package:openair/model/hive_models/history_model.dart';
import 'package:openair/model/hive_models/podcast_model.dart';
import 'package:openair/model/hive_models/subscription_model.dart';
import 'package:openair/providers/hive_provider.dart';
import 'package:openair/services/audio_handler.dart';
import 'package:openair/services/fyyd_provider.dart';
import 'package:openair/services/podcast_index_service.dart';

import 'package:openair/views/nav_pages/feeds_page.dart';
import 'package:openair/views/nav_pages/history_page.dart';
import 'package:openair/views/nav_pages/inbox_page.dart';
import 'package:openair/views/nav_pages/queue_page.dart';
import 'package:openair/views/navigation/list_drawer.dart';
import 'package:opml/opml.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webfeed_plus/domain/rss_feed.dart';

final audioControllerProvider = ChangeNotifierProvider<AudioController>(
  (ref) => AudioController(ref),
);

enum DownloadStatus { downloaded, downloading, notDownloaded }

enum PlayingStatus { detail, buffering, playing, paused, stop }

class AudioController extends ChangeNotifier {
  AudioController(this.ref);

  final Ref ref;

  final OpenAirAudioHandler _audioHandler = getAudioHandler();
  OpenAirAudioHandler get audioHandler => _audioHandler;
  AudioPlayer get player => _audioHandler.player;

  PodcastModel? currentPodcast;
  Map<String, dynamic>? currentEpisode;
  Map<String, dynamic>? nextEpisode;

  bool isPodcastSelected = false;
  bool onceQueueComplete = false;
  bool isCompleted = false;
  bool isBannerDismissed = false;

  late String podcastTitle;
  late String podcastSubtitle;

  late String audioState;
  late String loadState;

  Duration playerPosition = Duration.zero;
  Duration playerTotalDuration = Duration.zero;

  late double podcastCurrentPositionInMilliseconds;
  late String currentPlaybackPositionString;
  late String currentPlaybackRemainingTimeString;
  late String? currentPlaybackDurationString;

  late PlayingStatus isPlaying = PlayingStatus.stop;

  BuildContext? _appContext;
  bool _isAutoPlayingNext = false;

  String? currentPodcastTimeRemaining;

  List<String> audioSpeedOptions = ['0.5x', '1.0x', '1.25x', '1.5x', '2.0x'];

  List downloadingPodcasts = [];

  Timer? _sleepTimer;
  int? _sleepTimerMinutes;
  int? _remainingSeconds;

  Timer? _positionSaveTimer;

  int? get sleepTimerMinutes => _sleepTimerMinutes;
  int? get remainingSeconds => _remainingSeconds;
  bool get isSleepTimerActive => _sleepTimerMinutes != null;

  void startSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimerMinutes = minutes;
    _remainingSeconds = minutes * 60;
    notifyListeners();

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSeconds = _remainingSeconds! - 1;
      if (_remainingSeconds! <= 0) {
        timer.cancel();
        _sleepTimerMinutes = null;
        _remainingSeconds = null;
        pausePlayback();
      }
      notifyListeners();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimerMinutes = null;
    _remainingSeconds = null;
    notifyListeners();
  }

  void _startPositionAutoSave() {
    _positionSaveTimer?.cancel();
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (isPlaying != PlayingStatus.playing) return;
      await updateHistoryPlaybackPosition();
      await _savePlayerState();
    });
  }

  void _stopPositionAutoSave() {
    _positionSaveTimer?.cancel();
    _positionSaveTimer = null;
  }

  Future<void> savePlayerState() async {
    await _savePlayerState();
  }

  Future<void> _savePlayerState() async {
    if (currentEpisode == null) return;
    final hiveService = ref.read(hiveServiceProvider);
    await hiveService.saveLastPlayedEpisode({
      'guid': currentEpisode!['guid'],
      'title': currentEpisode!['title'],
      'podcastTitle': currentEpisode!['podcastTitle'],
      'author': currentEpisode!['author'],
      'image': currentEpisode!['image'] ?? currentEpisode!['feedImage'] ?? '',
      'feedUrl': currentEpisode!['feedUrl'],
      'enclosureUrl': currentEpisode!['enclosureUrl'],
      'datePublished': currentEpisode!['datePublished'],
      'duration': currentEpisode!['duration'],
      'position': playerPosition.inMilliseconds,
    });
  }

  void dismissBanner() {
    isBannerDismissed = true;
    notifyListeners();
  }

  void restoreBanner() {
    isBannerDismissed = false;
    notifyListeners();
  }

  Icon getDownloadIcon(DownloadStatus downloadStatus) {
    Icon icon;
    switch (downloadStatus) {
      case DownloadStatus.notDownloaded:
        icon = const Icon(Icons.download_rounded);
        break;
      case DownloadStatus.downloading:
        icon = const Icon(Icons.downloading_rounded);
        break;
      case DownloadStatus.downloaded:
        icon = const Icon(Icons.download_done_rounded);
        break;
    }
    return icon;
  }

  Future<String> getDownloadsDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError(
          'File system operations are not supported on web.');
    }
    final hiveService = ref.read(hiveServiceProvider);
    final baseDir = hiveService.openAirDir;
    final downloadsDirPath = join(baseDir.path, '.downloaded_episodes');
    final downloadsDir = Directory(downloadsDirPath);
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir.path;
  }

  Future<String?> downloadPodcastImage(String? imageUrl, {Dio? dio}) async {
    try {
      if (kIsWeb || imageUrl == null || imageUrl.isEmpty) return null;
      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        return null;
      }

      final downloadsDir = await getDownloadsDirectory();
      final imagesDir = Directory(join(downloadsDir, 'images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final hash = sha256.convert(utf8.encode(imageUrl)).toString();
      final imagePath = join(imagesDir.path, '$hash.jpg');

      if (await File(imagePath).exists()) {
        return imagePath;
      }

      final downloader = dio ?? Dio();
      await downloader.download(imageUrl, imagePath);
      return imagePath;
    } catch (e) {
      debugPrint('Error downloading podcast image: $e');
      return null;
    }
  }

  Future<bool> isAudioDownloaded(String guid) async {
    if (kIsWeb) return false;
    final filename = '$guid.mp3';
    final downloadsDir = await getDownloadsDirectory();
    final filePath = join(downloadsDir, filename);
    return File(filePath).exists();
  }

  Future<void> playEpisode(
    Map<String, dynamic> episodeItem,
    BuildContext context,
  ) async {
    currentEpisode = episodeItem;
    if (currentPodcast == null) {
      await _resolvePodcastFromEpisode(currentEpisode!);
    }
    if (currentPodcast != null) {
      if (currentEpisode!['podcastTitle'] == null) {
        currentEpisode!['podcastTitle'] = currentPodcast!.title;
      }
      if (currentEpisode!['author'] == null ||
          currentEpisode!['author'].isEmpty) {
        currentEpisode!['author'] = currentPodcast!.author;
      }
    }
    final bool isDownloaded = await isAudioDownloaded(currentEpisode!['guid']);

    isPodcastSelected = true;
    onceQueueComplete = false;
    isCompleted = false;
    isBannerDismissed = false;

    final imageUrl =
        currentEpisode!['image'] ?? currentEpisode!['feedImage'] ?? '';
    final title = currentEpisode!['title'] ?? 'Unknown';
    final artist = currentEpisode!['author'] ??
        currentEpisode!['podcastTitle'] ??
        'Unknown';

    try {

      await _audioHandler.setMediaItem(
        id: currentEpisode!['guid'],
        title: title,
        artist: artist,
        album: currentEpisode!['podcastTitle'] ?? '',
        artUri: imageUrl,
      );

      final resumePosition = episodeItem['position'] != null
          ? Duration(milliseconds: (episodeItem['position'] as num).toInt())
          : Duration.zero;

      if (isDownloaded) {
        final downloadsDir = await getDownloadsDirectory();
        final filePath = join(downloadsDir, '${episodeItem['guid']}.mp3');
        await _audioHandler.playFromFile(filePath,
            initialPosition: resumePosition);
      } else {
        await _audioHandler.playFromUrl(currentEpisode!['enclosureUrl'],
            initialPosition: resumePosition);
      }

      Future.delayed(Duration(seconds: 3), () {
        final duration = _audioHandler.duration;
        if (duration != null) {
          currentPlaybackDurationString = formatPlaybackPosition(duration);
        }
      });

      isPlaying = PlayingStatus.playing;
      audioState = 'Play';
      loadState = 'Play';
      nextEpisode = currentEpisode;

      await addToHistory(currentEpisode!, currentPodcast,
          author: currentEpisode!['author']);
      _startPositionAutoSave();
      await _savePlayerState();
      notifyListeners();
    } on TimeoutException {
      _handlePlaybackError();
    } catch (e) {
      _handlePlaybackError();
    }

    if (imageUrl.isNotEmpty) {
      _resizeAndCacheImage(imageUrl).then((localPath) {
        if (localPath != null) {
          _audioHandler.updateArtUri(localPath);
        }
      });
    }
  }

  void _handlePlaybackError() {
    _stopPositionAutoSave();
    isPlaying = PlayingStatus.stop;
    audioState = 'Stop';
    loadState = 'Detail';
    notifyListeners();
  }

  Future<void> resumePlayback() async {
    if (_audioHandler.player.processingState == ProcessingState.idle &&
        currentEpisode != null) {
      final isDownloaded = await isAudioDownloaded(currentEpisode!['guid']);
      if (isDownloaded) {
        final downloadsDir = await getDownloadsDirectory();
        final filePath = join(downloadsDir, '${currentEpisode!['guid']}.mp3');
        await _audioHandler.playFromFile(filePath,
            initialPosition: playerPosition);
      } else {
        await _audioHandler.playFromUrl(currentEpisode!['enclosureUrl'],
            initialPosition: playerPosition);
      }
    } else {
      await _audioHandler.play();
    }
    _startPositionAutoSave();
    audioState = 'Play';
    loadState = 'Play';
    isPlaying = PlayingStatus.playing;
    isCompleted = false;
    notifyListeners();
  }

  Future<void> updateHistoryPlaybackPosition({int? positionOverride}) async {
    if (currentEpisode == null) return;
    final hiveService = ref.read(hiveServiceProvider);
    final existing = await hiveService.getHistoryEntry(currentEpisode!['guid']);
    if (existing != null) {
      existing.position = positionOverride ?? playerPosition.inMilliseconds;
      await hiveService.addToHistory(existing);
    }
  }

  Future<void> pausePlayback() async {
    await updateHistoryPlaybackPosition();
    _stopPositionAutoSave();
    await _savePlayerState();
    await _audioHandler.pause();
    audioState = 'Pause';
    loadState = 'Detail';
    isPlaying = PlayingStatus.paused;
    notifyListeners();
  }

  void rewind() {
    if (playerPosition.inSeconds - int.parse(rewindIntervalConfig) > 0) {
      _audioHandler.seek(Duration(
          seconds: playerPosition.inSeconds - int.parse(rewindIntervalConfig)));
    }
  }

  void fastForward() {
    if (playerPosition.inSeconds + int.parse(fastForwardIntervalConfig) <
        playerTotalDuration.inSeconds) {
      _audioHandler.seek(Duration(
          seconds:
              playerPosition.inSeconds + int.parse(fastForwardIntervalConfig)));
    }
  }

  void cyclePlaybackSpeed() {
    final int index = audioSpeedOptions.indexOf(playbackSpeedConfig);
    final int newIndex = (index + 1) % audioSpeedOptions.length;
    playbackSpeedConfig = audioSpeedOptions[newIndex];
    _audioHandler.setSpeed(double.parse(playbackSpeedConfig.split('x').first));
    notifyListeners();
  }

  void seekTo(double sliderValue) {
    final Duration duration = Duration(
        milliseconds:
            (sliderValue * playerTotalDuration.inMilliseconds).toInt());
    podcastCurrentPositionInMilliseconds =
        ((sliderValue * playerTotalDuration.inMilliseconds) /
                playerTotalDuration.inMilliseconds)
            .clamp(0.0, 1.0);
    _audioHandler.seek(duration);
    notifyListeners();
  }

  String formatPlaybackPosition(Duration timeline) {
    final int hours = timeline.inHours;
    final int minutes = timeline.inMinutes % 60;
    final int seconds = timeline.inSeconds % 60;
    return "${hours != 0 ? hours < 10 ? '0$hours:' : '$hours:' : '00:'}${minutes != 0 ? minutes < 10 ? '0$minutes:' : '$minutes:' : '00:'}${seconds != 0 ? seconds < 10 ? '0$seconds' : '$seconds' : '00'}";
  }

  String getEpisodeSize(int size) {
    if (size < 1024) {
      return '$size Bytes';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    } else {
      final double sizeMB = size / (1024 * 1024);
      if (sizeMB < 1024) {
        return '${sizeMB.toStringAsFixed(2)} MB';
      } else {
        return '${(sizeMB / 1024).toStringAsFixed(2)} GB';
      }
    }
  }

  Future<void> downloadEpisode(
    Map<String, dynamic> item,
    PodcastModel podcast,
    BuildContext? context,
  ) async {
    final hiveService = ref.read(hiveServiceProvider);
    final downloadLimitString = downloadEpisodeLimitConfig;
    final downloadLimit = downloadLimitString != 'Unlimited'
        ? int.tryParse(downloadLimitString)
        : null;
    final downloadedCount = await hiveService.downloadsCount();

    if (downloadLimit != null && downloadedCount >= downloadLimit) {
      return;
    }

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'User-Agent':
            'OpenAir/1.0.0 (Podcast App; +https://github.com/OpenAir-Podcast/OpenAir)',
      },
    ));
    final guid = item['guid'] as String;
    final url = item['enclosureUrl'] as String;
    final size = getEpisodeSize(item['enclosureLength']);

    if (downloadingPodcasts.contains(guid)) return;
    downloadingPodcasts.add(guid);
    notifyListeners();

    try {
      final filename = '${item['guid']}.mp3';
      final downloadsDir = await getDownloadsDirectory();
      final savePath = join(downloadsDir, filename);
      await dio.download(url, savePath);

      final imageUrl = item['image'] ?? item['feedImage'];
      final localImagePath = await downloadPodcastImage(imageUrl, dio: dio);

      final downloadModel = DownloadModel(
        guid: guid,
        image: localImagePath ?? imageUrl,
        title: item['title'],
        author: podcast.author!,
        datePublished: item['datePublished'],
        description: item['description'],
        feedUrl: item['feedUrl'],
        duration: item['duration'],
        size: size,
        podcastId: podcast.id,
        enclosureLength: item['enclosureLength'],
        enclosureUrl: item['enclosureUrl'],
        downloadDate: DateTime.now(),
        fileName: filename,
      );

      await hiveService.addToDownloads(downloadModel);
      ref.invalidate(getDownloadsProvider);
      ref.invalidate(downloadsCountProvider);
      ref.invalidate(getDownloadsProvider);
    } catch (e) {
      debugPrint('Error downloading ${item['title']}: $e');
      final filename = '${item['guid']}.mp3';
      final filePath = await getDownloadsDirectory();
      final file = File('$filePath/$filename');
      if (await file.exists()) await file.delete();
    } finally {
      downloadingPodcasts.remove(guid);
      notifyListeners();
    }
  }

  Future<void> removeDownload(Map<String, dynamic> item) async {
    if (kIsWeb) return;
    final guid = item['guid'] as String;
    try {
      final filename = '${item['guid']}.mp3';
      final filePath = await getDownloadsDirectory();
      final file = File('$filePath/$filename');
      if (await file.exists()) await file.delete();
      final hiveService = ref.read(hiveServiceProvider);
      await hiveService.deleteDownload(guid);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing download for ${item['title']}: $e');
    }
  }

  Future<void> removeAllDownloads(BuildContext context) async {
    if (kIsWeb) return;
    try {
      final downloadsDirPath = await getDownloadsDirectory();
      final downloadsDirectory = Directory(downloadsDirPath);
      if (await downloadsDirectory.exists()) {
        await for (final entity in downloadsDirectory.list()) {
          await entity.delete(recursive: true);
        }
      }
      final hiveService = ref.read(hiveServiceProvider);
      await hiveService.clearDownloads();
      ref.invalidate(getDownloadsProvider);
      ref.invalidate(getDownloadsProvider);
      ref.invalidate(downloadsCountProvider);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing all downloaded podcasts: $e');
    }
  }

  String? _validImage(dynamic v) {
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  Future<void> addToHistory(Map<String, dynamic> episode, PodcastModel? podcast,
      {String? author}) async {
    final String downloadSize = getEpisodeSize(episode['enclosureLength']);
    String historyPodcastId;
    String historyPodcastImage;
    String? historyPodcastAuthor = author;

    if (historyPodcastAuthor == null) {
      if (podcast != null) {
        historyPodcastId = podcast.id.toString();
        historyPodcastImage = _validImage(episode['image']) ??
            _validImage(episode['feedImage']) ??
            podcast.imageUrl;
        historyPodcastAuthor = podcast.author ?? episode['author'] ?? 'Unknown';
      } else {
        historyPodcastId = episode['podcastId']?.toString() ?? '-1';
        historyPodcastImage = episode['image'] ?? '';
        historyPodcastAuthor =
            episode['author'] ?? episode['podcastTitle'] ?? 'Unknown';
      }

      // Try to get author from subscriptions if still unknown
      if (historyPodcastAuthor == 'Unknown' && historyPodcastId != '-1') {
        final subs = await ref.read(hiveServiceProvider).getSubscriptions();
        for (final entry in subs.entries) {
          if (entry.value.id.toString() == historyPodcastId) {
            historyPodcastAuthor = entry.value.author ?? 'Unknown';
            break;
          }
        }
      }
    } else {
      historyPodcastId =
          podcast?.id.toString() ?? episode['podcastId']?.toString() ?? '-1';
      historyPodcastImage = _validImage(episode['image']) ??
          _validImage(episode['feedImage']) ??
          podcast?.imageUrl ??
          '';
    }

    final HistoryModel historyMod = HistoryModel(
      guid: episode['guid'],
      image: historyPodcastImage,
      title: episode['title'],
      author: historyPodcastAuthor!,
      datePublished: episode['datePublished'],
      description: episode['description'],
      feedUrl: episode['feedUrl'],
      duration: episode['duration'],
      size: downloadSize,
      podcastId: historyPodcastId,
      enclosureLength: episode['enclosureLength'],
      enclosureUrl: episode['enclosureUrl'],
      playDate: DateTime.now().millisecondsSinceEpoch,
      position: (episode['position'] as num?)?.toInt() ?? 0,
    );

    final hiveService = ref.read(hiveServiceProvider);
    await hiveService.addToHistory(historyMod);
    await hiveService.deleteFromFeed(guid: episode['guid']);
    ref.invalidate(getHistoryProvider);
    ref.invalidate(getInboxProvider);
  }

  Future<void> addToQueue(
      Map<String, dynamic> episode, PodcastModel? podcast, BuildContext context,
      {bool autoDownload = false}) async {
    final hiveService = ref.read(hiveServiceProvider);
    final queue = await hiveService.getQueue();

    List<Map<String, dynamic>> queueList =
        queue.values.map((e) => Map<String, dynamic>.from(e)).toList();
    queueList.sort((a, b) => a['pos'].compareTo(b['pos']));

    int pos;
    switch (enqueuePositionConfig) {
      case 'First':
        pos = 1;
        for (var item in queueList) {
          item['pos'] = item['pos'] + 1;
          await hiveService.addToQueue(item);
        }
        break;
      case 'Last':
        pos = queue.isEmpty ? 1 : queueList.last['pos'] + 1;
        break;
      case 'After current episode':
        if (currentEpisode != null && currentEpisode!.isNotEmpty) {
          pos = queue.isEmpty
              ? 1
              : (queueList
                          .where((e) => e['guid'] == currentEpisode!['guid'])
                          .firstOrNull?['pos'] ??
                      queueList.last['pos']) +
                  1;
          for (var item in queueList) {
            if (item['pos'] >= pos) {
              item['pos'] = item['pos'] + 1;
              await hiveService.addToQueue(item);
            }
          }
        } else {
          pos = queue.isEmpty ? 1 : queueList.last['pos'] + 1;
        }
        break;
      default:
        pos = queue.isEmpty ? 1 : queueList.last['pos'] + 1;
    }

    hiveService.addToQueue({
      'guid': episode['guid'],
      'title': episode['title'],
      'author': episode['author'],
      'image': episode['feedImage'] ?? episode['image'],
      'datePublished': episode['datePublished'],
      'description': episode['description'],
      'feedUrl': episode['feedUrl'],
      'duration': episode['duration'],
      'downloadSize': getEpisodeSize(episode['enclosureLength']),
      'enclosureType': episode['enclosureType'] ?? 'audio/mpeg',
      'enclosureLength': episode['enclosureLength'],
      'enclosureUrl': episode['enclosureUrl'],
      'podcast': podcast!.toJson(),
      'pos': pos,
      'podcastCurrentPositionInMilliseconds': 0.0,
      'currentPlaybackPositionString': formatPlaybackPosition(Duration.zero),
      'currentPlaybackRemainingTimeString': '',
      'playerPosition': Duration.zero.inMilliseconds,
    });

    if (autoDownload) {
      await downloadEpisode(episode, podcast, null);
    }

    ref.invalidate(getQueueProvider);
    notifyListeners();
  }

  Future<void> removeFromQueue(String guid) async {
    final hiveService = ref.read(hiveServiceProvider);
    await hiveService.removeFromQueue(guid: guid);
    ref.invalidate(sortedProvider);
    ref.invalidate(getQueueProvider);
    notifyListeners();
  }

  Future<void> addPodcastEpisodes(
      SubscriptionModel podcast, BuildContext? context) async {
    final podcastIndexService = ref.read(podcastIndexProvider);
    final episodes =
        await podcastIndexService.getEpisodesByFeedUrl(podcast.feedUrl);
    final hiveService = ref.read(hiveServiceProvider);

    for (int i = 0; i < episodes['count']; i++) {
      final guid = episodes['items'][i]['guid'];
      final episode = {
        'podcastId': podcast.id.toString(),
        'podcastTitle': podcast.title,
        'guid': guid,
        'title': episodes['items'][i]['title'],
        'author': podcast.author,
        'image': episodes['items'][i]['feedImage'],
        'datePublished': episodes['items'][i]['datePublished'],
        'description': episodes['items'][i]['description'],
        'feedUrl': episodes['items'][i]['feedUrl'],
        'duration': episodes['items'][i]['duration'],
        'size': getEpisodeSize(episodes['items'][i]['enclosureLength']),
        'enclosureLength': episodes['items'][i]['enclosureLength'],
        'enclosureUrl': episodes['items'][i]['enclosureUrl'],
        'podcast': {
          'id': podcast.id,
          'title': podcast.title,
          'author': podcast.author,
          'url': podcast.feedUrl,
          'image': podcast.imageUrl,
          'artwork': podcast.artwork,
          'description': podcast.description,
        },
      };
      await hiveService.insertEpisode(episode, guid);
      await hiveService.addToFeed(FeedModel(guid: guid));
    }

    ref.invalidate(feedCountProvider);
    ref.invalidate(getInboxProvider);
    ref.invalidate(inboxCountProvider);
    notifyListeners();
  }

  Future<void> subscribeToPodcast(
      PodcastModel podcast, BuildContext? context) async {
    try {
      final podcastIndexService = ref.read(podcastIndexProvider);
      final podcastEpisodeCount = await podcastIndexService
          .getPodcastEpisodeCountByPodcastId(podcast.id);

      final subscription = SubscriptionModel(
        id: podcast.id,
        title: podcast.title,
        author: podcast.author,
        feedUrl: podcast.feedUrl,
        imageUrl: podcast.imageUrl,
        episodeCount: podcastEpisodeCount,
        description: podcast.description,
        artwork: podcast.artwork,
        updatedAt: DateTime.now(),
      );

      final hiveService = ref.read(hiveServiceProvider);
      await hiveService.subscribe(subscription);
      if (context != null && context.mounted) {
        await addPodcastEpisodes(subscription, context);
      } else {
        await addPodcastEpisodes(subscription, null);
      }

      ref.invalidate(getSubscribedEpisodesProvider);
      ref.invalidate(subscriptionsProvider);
      ref.invalidate(subCountProvider);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to subscribe to ${podcast.title}: $e');
    }
  }

  Future<void> unsubscribeFromPodcast(PodcastModel podcast) async {
    final hiveService = ref.read(hiveServiceProvider);
    await hiveService.unsubscribe(podcast.title);
    await hiveService.removePodcastEpisodes(podcast);
    ref.invalidate(getSubscribedEpisodesProvider);
    ref.invalidate(subscriptionsProvider);
    ref.invalidate(subCountProvider);
    ref.invalidate(inboxCountProvider);
    notifyListeners();
  }

  Future<bool> addPodcastByRssUrl(String rssUrl, BuildContext context) async {
    try {
      final fyydProviderService = ref.read(fyydProvider);
      final xmlString =
          await fyydProviderService.getPodcastXml(rssUrl, context);
      final rssFeed = RssFeed.parse(xmlString);

      final subscription = SubscriptionModel(
        id: 0,
        title: rssFeed.title!,
        author: rssFeed.itunes?.author ?? rssFeed.dc?.creator ?? 'Unknown',
        feedUrl: rssUrl,
        imageUrl: rssFeed.itunes!.image!.href!,
        episodeCount: 0,
        description: rssFeed.description!,
        artwork: rssFeed.itunes!.image!.href!,
        updatedAt: DateTime.now(),
      );

      if (context.mounted) {
        await subscribeToPodcastByRssFeed(subscription, context);
      }
      return true;
    } catch (e) {
      debugPrint('Failed to add podcast by RSS URL: $e');
      return false;
    }
  }

  Future<void> subscribeToPodcastByRssFeed(
      SubscriptionModel podcast, BuildContext context) async {
    try {
      final podcastIndexService = ref.read(podcastIndexProvider);
      final podcastEpisodeCount = await podcastIndexService
          .getPodcastEpisodeCountByTitle(podcast.title);

      final subscription = SubscriptionModel(
        id: podcast.id,
        title: podcast.title,
        author: podcast.author,
        feedUrl: podcast.feedUrl,
        imageUrl: podcast.imageUrl,
        episodeCount: podcastEpisodeCount,
        description: podcast.description,
        artwork: podcast.artwork,
        updatedAt: DateTime.now(),
      );

      final hiveService = ref.read(hiveServiceProvider);
      await hiveService.subscribe(subscription);
      if (context.mounted) await addPodcastEpisodes(subscription, context);
      ref.invalidate(getSubscribedEpisodesProvider);
      ref.invalidate(subscriptionsProvider);
      ref.invalidate(subCountProvider);
    } catch (e) {
      debugPrint('Failed to subscribe (RSS Feed) to ${podcast.title}: $e');
      rethrow;
    }
  }

  Future<void> addEpisodeToFavorite(
      Map<String, dynamic> episode, PodcastModel podcast,
      {String? author}) async {
    final hiveService = ref.read(hiveServiceProvider);
    episode['author'] = author;
    podcast.author = author;
    episode['podcast'] = podcast;
    hiveService.addEpisodeToFavorite(episode, podcast, author: author);
    ref.invalidate(getFavoriteProvider);
  }

  Future<void> removeEpisodeFromFavorite(String guid) async {
    final hiveService = ref.read(hiveServiceProvider);
    hiveService.removeEpisodeFromFavorite(guid);
    ref.invalidate(getFavoriteProvider);
  }

  Future<bool> isAudioFileDownloaded(String guid) => isAudioDownloaded(guid);

  Future<void> initAudio(BuildContext context) => initializeAudio(context);

  void updateAppContext(BuildContext? context) {
    if (context != null && context.mounted) {
      _appContext = context;
    }
  }

  Future<void> initializeAudio(BuildContext context) async {
    _appContext = context;

    _audioHandler.onSkipToNext = () => playNextEpisode(_appContext);
    _audioHandler.onSkipToPrevious = () => playPreviousEpisode(_appContext);

    // Set up position listener
    _audioHandler.positionStream.listen((Duration position) {
      if (isPlaying == PlayingStatus.buffering) return;

      playerPosition = position;
      currentPlaybackPositionString = formatPlaybackPosition(position);

      if (playerTotalDuration.inMilliseconds > 0) {
        podcastCurrentPositionInMilliseconds =
            (position.inMilliseconds / playerTotalDuration.inMilliseconds)
                .clamp(0.0, 1.0);

        final remaining = playerTotalDuration - position;
        currentPodcastTimeRemaining = formatPlaybackPosition(remaining);
      } else {
        podcastCurrentPositionInMilliseconds = 0.0;
      }

      notifyListeners();
    });

    // Set up duration listener
    _audioHandler.durationStream.listen((Duration? duration) {
      if (duration != null) {
        playerTotalDuration = duration;
        currentPlaybackDurationString = formatPlaybackPosition(duration);
        notifyListeners();
      }
    });

    // Set up player state listener
    _audioHandler.playerStateStream.listen((PlayerState state) async {
      switch (state.processingState) {
        case ProcessingState.ready:
          if (state.playing) {
            isPlaying = PlayingStatus.playing;
            audioState = 'Play';
            loadState = 'Play';
          } else {
            isPlaying = PlayingStatus.paused;
            audioState = 'Pause';
            loadState = 'Detail';
          }
          break;
        case ProcessingState.buffering:
          isPlaying = PlayingStatus.buffering;
          audioState = 'Play';
          loadState = 'Detail';
          break;
        case ProcessingState.completed:
          if (_isAutoPlayingNext) break;
          _isAutoPlayingNext = true;
          _stopPositionAutoSave();
          try {
            await updateHistoryPlaybackPosition(positionOverride: 0);
            await _savePlayerState();
            if (_appContext != null) {
              if (autoplayNextInQueueConfig) {
                await _autoPlayNextFromQueue(_appContext!);
              } else {
                await _playNextFromPodcast(_appContext!, stopOnEnd: true);
              }
            }
          } catch (_) {
            _isAutoPlayingNext = false;
          }
          break;
        case ProcessingState.idle:
          if (_isAutoPlayingNext) {
            _isAutoPlayingNext = false;
          } else {
            isPlaying = PlayingStatus.stop;
            audioState = 'Stop';
            loadState = 'Detail';
          }
          break;
        default:
          break;
      }
      notifyListeners();
    });

    _restoreLastPlayedEpisode();

    // Push the local media library to the audio handler so Android Auto and
    // assistant voice commands can browse and play subscribed content.
    syncMediaLibrary();
  }

  Future<void> syncMediaLibrary() async {
    final hiveService = ref.read(hiveServiceProvider);

    final subscriptionsMap = await hiveService.getSubscriptions();
    final allEpisodes = await hiveService.getEpisodes();

    final podcasts = <MediaItem>[];
    final episodesByPodcast = <String, List<MediaItem>>{};
    final urlsByGuid = <String, String>{};

    for (final subscription in subscriptionsMap.values) {
      final podcastId = subscription.id.toString();
      podcasts.add(MediaItem(
        id: podcastId,
        title: subscription.title,
        artist: subscription.author,
        album: null,
        artUri: _parseArtUri(
            subscription.artwork.isNotEmpty
                ? subscription.artwork
                : subscription.imageUrl),
        duration: null,
      ));
      episodesByPodcast[podcastId] = [];
    }

    for (final episode in allEpisodes) {
      final podcastId =
          ((episode['podcast'] as Map?)?['id'] ?? episode['podcastId'])
              ?.toString();
      final guid = episode['guid']?.toString();
      final url = episode['enclosureUrl']?.toString() ?? '';
      if (podcastId == null ||
          podcastId.isEmpty ||
          guid == null ||
          guid.isEmpty ||
          url.isEmpty) {
        continue;
      }

      final podcastTitle =
          ((episode['podcast'] as Map?)?['title'] ?? episode['podcastTitle'])
              ?.toString();
      final author = episode['author']?.toString();
      final title = episode['title']?.toString() ?? 'Unknown';
      final image = episode['image']?.toString() ??
          episode['feedImage']?.toString() ??
          '';

      final item = MediaItem(
        id: guid,
        title: title,
        artist: (author != null && author.isNotEmpty) ? author : podcastTitle,
        album: (podcastTitle != null && podcastTitle.isNotEmpty)
            ? podcastTitle
            : null,
        artUri: _parseArtUri(image),
        duration: _parseEpisodeDuration(episode['duration']),
      );

      (episodesByPodcast[podcastId] ??= []).add(item);
      urlsByGuid[guid] = url;
    }

    _audioHandler.updateMediaLibrary(
      podcasts: podcasts,
      episodesByPodcast: episodesByPodcast,
      urlsByGuid: urlsByGuid,
    );
  }

  Uri? _parseArtUri(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Uri.parse(url);
    }
    return null;
  }

  Duration? _parseEpisodeDuration(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return Duration(seconds: raw);

    final parts = raw.toString().split(':');
    if (parts.length == 3) {
      return Duration(
        hours: int.tryParse(parts[0]) ?? 0,
        minutes: int.tryParse(parts[1]) ?? 0,
        seconds: int.tryParse(parts[2]) ?? 0,
      );
    }
    if (parts.length == 2) {
      return Duration(
        minutes: int.tryParse(parts[0]) ?? 0,
        seconds: int.tryParse(parts[1]) ?? 0,
      );
    }
    final seconds = int.tryParse(parts[0]);
    return seconds != null ? Duration(seconds: seconds) : null;
  }

  Future<void> _restoreLastPlayedEpisode() async {
    final hiveService = ref.read(hiveServiceProvider);
    final saved = await hiveService.getLastPlayedEpisode();
    if (saved == null) return;

    final guid = saved['guid'] as String?;
    final position = saved['position'] as int?;
    if (guid == null || position == null || position <= 0) return;

    final historyEntry = await hiveService.getHistoryEntry(guid);
    final episodeBox = await hiveService.episodeBox;
    final storedEpisode = await episodeBox.get(guid);

    if (historyEntry == null && storedEpisode == null) {
      await hiveService.clearLastPlayedEpisode();
      return;
    }

    currentEpisode = storedEpisode != null
        ? Map<String, dynamic>.from(storedEpisode)
        : {
            'guid': guid,
            'title': saved['title'],
            'podcastTitle': saved['podcastTitle'],
            'author': saved['author'],
            'image': saved['image'],
            'feedUrl': saved['feedUrl'],
            'enclosureUrl': saved['enclosureUrl'],
            'datePublished': saved['datePublished'],
            'duration': saved['duration'],
          };

    if (currentEpisode!['podcastTitle'] == null ||
        currentEpisode!['podcastTitle'].isEmpty) {
      currentEpisode!['podcastTitle'] = saved['podcastTitle'];
    }
    if (currentEpisode!['author'] == null ||
        currentEpisode!['author'].isEmpty) {
      currentEpisode!['author'] = saved['author'];
    }

    await _resolvePodcastFromEpisode(currentEpisode!);

    playerPosition = Duration(milliseconds: position);
    isPlaying = PlayingStatus.paused;
    audioState = 'Pause';
    loadState = 'Detail';
    isPodcastSelected = true;

    final imageUrl =
        saved['image'] as String? ?? currentEpisode!['image'] as String? ?? '';
    final title = currentEpisode!['title'] as String? ?? 'Unknown';
    final artist = currentEpisode!['author'] as String? ??
        currentEpisode!['podcastTitle'] as String? ??
        'Unknown';
    await _audioHandler.setMediaItem(
      id: guid,
      title: title,
      artist: artist,
      album: currentEpisode!['podcastTitle'] as String? ?? '',
      artUri: imageUrl,
    );

    notifyListeners();
  }

  Future<void> playerPlayButtonClicked(
    Map<String, dynamic> episodeItem,
    BuildContext context,
  ) async {
    await playEpisode(episodeItem, context);
  }

  String getPodcastPublishedDateFromEpoch(int epoch) {
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  Future<void> subscribe(PodcastModel podcast, BuildContext context) async {
    await subscribeToPodcast(podcast, context);
  }

  Future<void> unsubscribe(PodcastModel podcast) async {
    await unsubscribeFromPodcast(podcast);
  }

  Future<bool> importPodcastFromOpml(BuildContext context) async {
    return await importOpml(context);
  }

  Future<bool> importOpml(BuildContext context) async {
    String defaultFilePath;

    if (Platform.isAndroid) {
      defaultFilePath = '/storage/emulated/0/Download';
    } else if (Platform.isIOS) {
      defaultFilePath = (await getApplicationDocumentsDirectory()).path;
    } else {
      defaultFilePath = await getDownloadsDirectory();
    }

    if (!context.mounted) return false;

    final result = await FilePicker.pickFile(
      dialogTitle: 'Import OPML',
      type: FileType.custom,
      allowedExtensions: ['opml'],
      initialDirectory: defaultFilePath,
    );

    if (result != null) {
      File file = File(result.path!);
      final xml = file.readAsStringSync();
      final doc = OpmlDocument.parse(xml);

      for (var feed in doc.body) {
        if (context.mounted) await addPodcastByRssUrl(feed.xmlUrl!, context);
      }
      return true;
    }
    return false;
  }

  Future<void> removeAllDownloadedPodcasts(BuildContext context) async {
    await removeAllDownloads(context);
  }

  Future<void> playerPauseButtonClicked() => pausePlayback();

  Future<void> playerResumeButtonClicked() => resumePlayback();

  void mainPlayerSliderClicked(double sliderValue) => seekTo(sliderValue);

  DateTime? _lastPreviousTapTime;

  Future<void> playPreviousEpisode([BuildContext? context]) async {
    context ??= _appContext;
    final now = DateTime.now();
    if (_lastPreviousTapTime != null &&
        now.difference(_lastPreviousTapTime!) <
            const Duration(milliseconds: 400)) {
      _lastPreviousTapTime = null;

      await _audioHandler.stop();
      final hiveService = ref.read(hiveServiceProvider);
      Map queueMap = await hiveService.getQueue();

      if (queueMap.isNotEmpty) {
        List<Map<String, dynamic>> queueList =
            queueMap.values.map((e) => Map<String, dynamic>.from(e)).toList();
        queueList.sort((a, b) => (a['pos'] as int).compareTo(b['pos'] as int));

        int currentEpisodeIndex = -1;
        for (int i = 0; i < queueList.length; i++) {
          if (queueList[i]['guid'] == currentEpisode!['guid']) {
            currentEpisodeIndex = i;
            break;
          }
        }

        if (!keepSkippedEpisodesConfig) {
          await hiveService.removeFromQueue(guid: currentEpisode!['guid']);
        }

        if (currentEpisodeIndex == -1 || currentEpisodeIndex == 0) {
          _isNavigatingPodcast = false;
          await _playPreviousFromPodcast(context);
          return;
        }

        await updateCurrentQueueCard(
          currentEpisode!['guid'],
          podcastCurrentPositionInMilliseconds,
          currentPlaybackPositionString,
          currentPlaybackRemainingTimeString,
          playerPosition,
        );

        Map<String, dynamic> previousEpisode =
            queueList[currentEpisodeIndex - 1];
        currentEpisode = previousEpisode;
        if (currentEpisode!['author'] == null ||
            currentEpisode!['author'].isEmpty) {
          currentEpisode!['author'] = currentPodcast?.author;
        }
        currentPodcast = previousEpisode['podcast'];

        if (context != null && context.mounted) {
          await queuePlayButtonClicked(
            previousEpisode,
            previousEpisode['playerPosition'],
            context,
          );
        }
      } else {
        _isNavigatingPodcast = false;
        await _playPreviousFromPodcast(context);
      }
      notifyListeners();
      return;
    }

    _lastPreviousTapTime = now;
    await _audioHandler.seek(Duration.zero);
    playerPosition = Duration.zero;
    notifyListeners();
  }

  bool _isNavigatingPodcast = false;

  Future<void> _playPreviousFromPodcast(BuildContext? context) async {
    context ??= _appContext;
    if (_isNavigatingPodcast) return;
    _isNavigatingPodcast = true;

    try {
      if (currentPodcast == null && currentEpisode != null) {
        await _resolvePodcastFromEpisode(currentEpisode!);
      }

      if (currentPodcast == null || currentEpisode == null) {
        return;
      }

      final sortedEpisodes = (await _getEpisodesForCurrentPodcast())
        ..sort((a, b) => b['datePublished'].compareTo(a['datePublished']));

      int currentIndex = _findEpisodeIndex(currentEpisode, sortedEpisodes);

      if (currentIndex == -1 || currentIndex >= sortedEpisodes.length - 1) {
        return;
      }

      await _audioHandler.stop();
      final previousEpisode = sortedEpisodes[currentIndex + 1];
      currentEpisode = previousEpisode;
      currentEpisode!['author'] = currentPodcast!.author;

      if (context != null && context.mounted) {
        await queuePlayButtonClicked(
          previousEpisode,
          Duration.zero,
          context,
        );
      }
    } finally {
      _isNavigatingPodcast = false;
    }
  }

  void rewindButtonClicked() => rewind();

  void fastForwardButtonClicked() => fastForward();

  void audioSpeedButtonClicked() => cyclePlaybackSpeed();

  String convertSecondsToDuration(int totalSeconds, BuildContext context) {
    if (totalSeconds <= 0) return '';

    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }

    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  Future<Map> getFavoriteEpisodes() async {
    final hiveService = ref.read(hiveServiceProvider);
    return await hiveService.getFavoriteEpisodes();
  }

  Future<void> queuePlayButtonClicked(
    Map<String, dynamic> queueItem,
    Duration position,
    BuildContext context,
  ) async {
    currentEpisode = queueItem;
    if (queueItem['podcast'] != null) {
      currentPodcast = queueItem['podcast'] is PodcastModel
          ? queueItem['podcast']
          : PodcastModel.fromJson(queueItem['podcast']);
    }
    if (currentPodcast == null) {
      await _resolvePodcastFromEpisode(currentEpisode!);
    }
    if (currentPodcast != null) {
      if (currentEpisode!['podcastTitle'] == null ||
          currentEpisode!['podcastTitle'].isEmpty) {
        currentEpisode!['podcastTitle'] = currentPodcast!.title;
      }
      if (currentEpisode!['author'] == null ||
          currentEpisode!['author'].isEmpty) {
        currentEpisode!['author'] = currentPodcast!.author;
      }
    }
    isPodcastSelected = true;
    onceQueueComplete = false;
    isCompleted = false;
    playerPosition = position;

    final isDownloaded = await isAudioDownloaded(queueItem['guid']);

    if (isDownloaded) {
      final filename = '${currentEpisode!['guid']}.mp3';
      final filePath = await getDownloadsDirectory();
      final file = File('$filePath/$filename');
      await _audioHandler.playFromFile(file.path, initialPosition: position);
    } else {
      await _audioHandler.playFromUrl(currentEpisode!['enclosureUrl'],
          initialPosition: position);
    }

    isPlaying = PlayingStatus.playing;
    audioState = 'Play';
    loadState = 'Play';
    nextEpisode = currentEpisode;

    await addToHistory(currentEpisode!, currentPodcast,
        author: currentEpisode!['author'] ?? currentPodcast?.author);
    notifyListeners();
  }

  Future<void> updateCurrentQueueCard(
    String guid,
    double podcastCurrentPositionInMilliseconds,
    String currentPlaybackPositionString,
    String currentPlaybackRemainingTimeString,
    Duration position,
  ) async {
    final hiveService = ref.read(hiveServiceProvider);
    final existingQueueItem = await hiveService.getQueueByGuid(guid);

    if (existingQueueItem != null) {
      existingQueueItem['podcastCurrentPositionInMilliseconds'] =
          podcastCurrentPositionInMilliseconds;
      existingQueueItem['currentPlaybackPositionString'] =
          currentPlaybackPositionString;
      existingQueueItem['currentPlaybackRemainingTimeString'] =
          currentPlaybackRemainingTimeString;
      existingQueueItem['playerPosition'] = position;
      await hiveService.addToQueue(existingQueueItem);
    }
  }

  Future<void> playNewQueueItem(
      Map<String, dynamic> newItem, BuildContext context) async {
    if ((isPlaying == PlayingStatus.playing ||
            isPlaying == PlayingStatus.paused) &&
        currentEpisode != null) {
      await updateCurrentQueueCard(
        currentEpisode!['guid'],
        podcastCurrentPositionInMilliseconds,
        currentPlaybackPositionString,
        currentPlaybackRemainingTimeString,
        playerPosition,
      );
    }

    if (context.mounted) {
      await queuePlayButtonClicked(newItem, newItem['playerPosition'], context);
    }
  }

  Future<void> _autoPlayNextFromQueue(BuildContext context) async {
    if (currentEpisode == null || currentEpisode!.isEmpty) {
      await _audioHandler.stop();
      isPlaying = PlayingStatus.stop;
      audioState = 'Stop';
      loadState = 'Detail';
      isCompleted = true;
      return;
    }

    final hiveService = ref.read(hiveServiceProvider);
    final queueMap = await hiveService.getQueue();

    if (queueMap.isEmpty) {
      _isNavigatingPodcast = false;
      await _playNextFromPodcast(context, stopOnEnd: true);
      return;
    }

    List<Map<String, dynamic>> queueList =
        queueMap.values.map((e) => Map<String, dynamic>.from(e)).toList();
    queueList.sort((a, b) => (a['pos'] as int).compareTo(b['pos'] as int));

    int currentEpisodeIndex = -1;
    for (int i = 0; i < queueList.length; i++) {
      if (queueList[i]['guid'] == currentEpisode!['guid']) {
        currentEpisodeIndex = i;
        break;
      }
    }

    if (!keepSkippedEpisodesConfig) {
      await hiveService.removeFromQueue(guid: currentEpisode!['guid']);
    }

    if (currentEpisodeIndex < 0 ||
        currentEpisodeIndex >= queueList.length - 1) {
      _isNavigatingPodcast = false;
      await _playNextFromPodcast(context, stopOnEnd: true);
      return;
    }

    await updateCurrentQueueCard(
      currentEpisode!['guid'],
      podcastCurrentPositionInMilliseconds,
      currentPlaybackPositionString,
      currentPlaybackRemainingTimeString,
      playerPosition,
    );

    await _audioHandler.stop();

    final nextEpisodeData = queueList[currentEpisodeIndex + 1];
    currentEpisode = nextEpisodeData;
    if (currentEpisode!['author'] == null ||
        currentEpisode!['author'].isEmpty) {
      currentEpisode!['author'] = currentPodcast?.author;
    }
    currentPodcast = nextEpisodeData['podcast'];

    if (context.mounted) {
      await queuePlayButtonClicked(
          nextEpisodeData, nextEpisodeData['playerPosition'], context);
    }
    notifyListeners();
  }

  Future<void> playNextEpisode([BuildContext? context]) async {
    context ??= _appContext;
    if (currentEpisode == null || currentEpisode!.isEmpty) return;

    final hiveService = ref.read(hiveServiceProvider);
    final queueMap = await hiveService.getQueue();

    if (queueMap.isNotEmpty) {
      List<Map<String, dynamic>> queueList =
          queueMap.values.map((e) => Map<String, dynamic>.from(e)).toList();
      queueList.sort((a, b) => (a['pos'] as int).compareTo(b['pos'] as int));

      int currentEpisodeIndex = -1;
      for (int i = 0; i < queueList.length; i++) {
        if (queueList[i]['guid'] == currentEpisode!['guid']) {
          currentEpisodeIndex = i;
          break;
        }
      }

      if (!keepSkippedEpisodesConfig) {
        await hiveService.removeFromQueue(guid: currentEpisode!['guid']);
      }

      if (currentEpisodeIndex == -1 ||
          currentEpisodeIndex == queueList.length - 1) {
        _isNavigatingPodcast = false;
        await _playNextFromPodcast(context);
        return;
      }

      await updateCurrentQueueCard(
        currentEpisode!['guid'],
        podcastCurrentPositionInMilliseconds,
        currentPlaybackPositionString,
        currentPlaybackRemainingTimeString,
        playerPosition,
      );

      await _audioHandler.stop();

      final nextEpisodeData = queueList[currentEpisodeIndex + 1];
      currentEpisode = nextEpisodeData;
      if (currentEpisode!['author'] == null ||
          currentEpisode!['author'].isEmpty) {
        currentEpisode!['author'] = currentPodcast?.author;
      }
      currentPodcast = nextEpisodeData['podcast'];

      if (context != null && context.mounted) {
        await queuePlayButtonClicked(
            nextEpisodeData, nextEpisodeData['playerPosition'], context);
      }
    } else {
      _isNavigatingPodcast = false;
      await _playNextFromPodcast(context);
    }

    notifyListeners();
  }

  int _findEpisodeIndex(
    Map<String, dynamic>? episode,
    List<Map<String, dynamic>> sortedEpisodes,
  ) {
    if (episode == null) return -1;

    int idx = sortedEpisodes
        .indexWhere((ep) => ep['guid'] == episode['guid']);
    if (idx >= 0) return idx;

    idx = sortedEpisodes
        .indexWhere((ep) => ep['id'] == episode['id']);
    if (idx >= 0) return idx;

    idx = sortedEpisodes.indexWhere(
        (ep) => ep['title'] == episode['title']);
    if (idx >= 0) return idx;

    final currentDate = episode['datePublished'];
    if (currentDate != null) {
      idx = sortedEpisodes.indexWhere(
          (ep) => ep['datePublished'] == currentDate);
    }
    return idx;
  }

  Future<List<Map<String, dynamic>>> _getEpisodesForCurrentPodcast() async {
    final podcastIndexService = ref.read(podcastIndexProvider);
    final feedUrl = currentPodcast!.feedUrl;
    if (feedUrl.isNotEmpty) {
      try {
        final response =
            await podcastIndexService.getEpisodesByFeedUrl(feedUrl);
        final items = response['items'] as List?;
        if (items != null && items.isNotEmpty) {
          return items.cast<Map<String, dynamic>>();
        }
      } catch (_) {}
    }

    final hiveService = ref.read(hiveServiceProvider);
    final fromHive =
        await hiveService.getEpisodesForPodcast(currentPodcast!.id.toString());
    if (fromHive.isNotEmpty) {
      return fromHive.map((e) => Map<String, dynamic>.from(e.value)).toList();
    }

    return [];
  }

  Future<void> _playNextFromPodcast(BuildContext? context,
      {bool stopOnEnd = false}) async {
    context ??= _appContext;
    if (_isNavigatingPodcast) return;
    _isNavigatingPodcast = true;

    try {
      if (currentPodcast == null && currentEpisode != null) {
        await _resolvePodcastFromEpisode(currentEpisode!);
      }

      if (currentPodcast == null || currentEpisode == null) {
        return;
      }

      final allEpisodes = await _getEpisodesForCurrentPodcast();
      final sortedEpisodes = allEpisodes
        ..sort((a, b) => b['datePublished'].compareTo(a['datePublished']));

      int currentIndex = _findEpisodeIndex(currentEpisode, sortedEpisodes);

      if (currentIndex <= 0) {
        if (stopOnEnd) {
          await _audioHandler.stop();
        }
        return;
      }

      await _audioHandler.stop();
      final nextEpisode = sortedEpisodes[currentIndex - 1];

      currentEpisode = nextEpisode;
      currentEpisode!['author'] = currentPodcast!.author;

      if (context != null && context.mounted) {
        await queuePlayButtonClicked(
          nextEpisode,
          Duration.zero,
          context,
        );
      }
    } finally {
      _isNavigatingPodcast = false;
    }
  }

  String formatCurrentPlaybackPosition(Duration timeline) {
    return formatPlaybackPosition(timeline);
  }

  Future<String?> _resizeAndCacheImage(String imageUrl,
      {int size = 300}) async {
    try {
      final response = await Dio().get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode != 200) return null;
      final data = response.data;
      if (data == null || data is! List<int>) return null;
      final bytes = Uint8List.fromList(data);
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: size,
        targetHeight: size,
      );
      final frame = await codec.getNextFrame();
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final dir = await getTemporaryDirectory();
      final cacheDir = Directory('${dir.path}/artwork');
      if (!await cacheDir.exists()) await cacheDir.create();
      final file = File(
          '${cacheDir.path}/${imageUrl.hashCode}_${size}x$size.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _resolvePodcastFromEpisode(Map<String, dynamic> episode) async {
    final podcast =
        episode['podcast'] is Map ? Map<String, dynamic>.from(episode['podcast']) : null;
    final feedId = episode['podcastId']?.toString() ??
        episode['feedId']?.toString() ??
        podcast?['id']?.toString();
    final feedUrl = episode['feedUrl'] as String? ??
        podcast?['url'] as String?;

    if ((feedId == null || feedId.isEmpty) &&
        (feedUrl == null || feedUrl.isEmpty)) {
      return;
    }

    final hiveService = ref.read(hiveServiceProvider);
    final subscriptions = await hiveService.getSubscriptions();

    for (final sub in subscriptions.values) {
      if (sub.id.toString() == feedId ||
          (feedUrl != null &&
              feedUrl.isNotEmpty &&
              sub.feedUrl == feedUrl)) {
        if (episode['podcastTitle'] == null ||
            episode['podcastTitle'].isEmpty) {
          episode['podcastTitle'] = sub.title;
        }
        if (episode['author'] == null || episode['author'].isEmpty) {
          episode['author'] = sub.author;
        }
        currentPodcast = PodcastModel(
          id: sub.id,
          feedUrl: sub.feedUrl,
          title: sub.title,
          author: sub.author,
          imageUrl: sub.imageUrl,
          artwork: sub.artwork,
          description: sub.description,
        );
        return;
      }
    }
  }
}
