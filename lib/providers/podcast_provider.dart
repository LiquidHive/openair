import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:http/http.dart' as http;

import 'package:openair/models/feed_model.dart';
import 'package:openair/models/episode_model.dart';
import 'package:openair/views/player/main_player.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final podcastProvider = ChangeNotifierProvider<PodcastProvider>(
  (ref) {
    return PodcastProvider();
  },
);

enum DownloadStatus { downloaded, downloading, notDownloaded }

enum PlayingStatus { detail, buffering, playing, paused }

class PodcastProvider with ChangeNotifier {
  late AudioPlayer player;
  late StreamSubscription? mPlayerSubscription;

  late BuildContext context;

  late String podcastTitle;
  late String podcastSubtitle;

  late String audioState; // Play, Pause, Stop
  late String loadState; // Play, Load, Detail

  late Duration podcastPosition;
  late Duration podcastDuration;

  late double podcastCurrentPositionInMilliseconds;
  late String currentPlaybackPositionString;
  late String currentPlaybackRemainingTimeString;

  final String storagePath = 'openair/downloads';

  late Directory directory;

  int navIndex = 1;

  bool isPodcastSelected = false;

// Main api feed from PodcastIndex.org
  late Map<String, dynamic> feed;

  late FeedModel? selectedPodcast;
  late EpisodeModel? selectedEpisode;

  List<FeedModel> feedPodcasts = [];
  List<EpisodeModel> episodeItems = [];

  List<String> downloadingPodcasts = [];

  late String? currentPodcastTimeRemaining;

  String audioSpeedButtonLabel = '1.0x';

  List<String> audioSpeedOptions = ['0.5x', '1.0x', '1.5x', '2.0x'];

  Future<void> initial(
    BuildContext context,
  ) async {
    player = AudioPlayer();

    this.context = context;

    podcastSubtitle = 'podcastImage';
    podcastTitle = 'episodeName';
    podcastSubtitle = 'name';

    podcastPosition = Duration.zero;
    podcastDuration = Duration.zero;

    podcastCurrentPositionInMilliseconds = 0;
    currentPlaybackPositionString = '00:00:00';
    currentPlaybackRemainingTimeString = '00:00:00';

    selectedEpisode = null;

    audioState = 'Pause';
    loadState = 'Detail'; // Play, Load, Detail

    directory = await getApplicationDocumentsDirectory();
  }

  void setNavIndex(int navIndex) {
    this.navIndex = navIndex;
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
      default:
        icon = const Icon(Icons.download_rounded);
    }

    return icon;
  }

  Future<void> bannerControllerClicked() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MainPlayer(),
      ),
    );
  }

  void audioPlayerSheetCloseButtonClicked() {}

  Future<List<String>> setPodcastStream(
    EpisodeModel episodeItem,
  ) async {
    loadState = 'Load';

    selectedEpisode ??= episodeItem;

    if (episodeItem != selectedEpisode) {
      selectedEpisode!.setPlayingStatus = PlayingStatus.detail;
    }

    episodeItem.setPlayingStatus = PlayingStatus.buffering;
    notifyListeners();

    // TODO: Add support for multiple podcast
    String mp3Name =
        formattedDownloadedPodcastName(episodeItem.getRssItem!.enclosure!.url!);
    // '';

    bool isDownloaded = await isMp3FileDownloaded(mp3Name);

    List<String> result = [mp3Name, isDownloaded.toString()];

    isDownloaded
        ? {
            await player.setSource(DeviceFileSource(
              episodeItem.rssItem!.enclosure!.url!,
              mimeType: episodeItem.rssItem!.enclosure!.type,
            ))
          }
        : await player.setSource(UrlSource(
            episodeItem.rssItem!.enclosure!.url!,
            mimeType: episodeItem.rssItem!.enclosure!.type,
          ));

    return result;
  }

  void rewindButtonClicked() {
    if (podcastPosition.inSeconds - 10 > 0) {
      player.seek(Duration(seconds: podcastPosition.inSeconds - 10));
    }
  }

  void playerPlayButtonClicked(
    EpisodeModel episodeItem,
  ) async {
    List<String> result = await setPodcastStream(episodeItem);

    isPodcastSelected = true;

    if (player.state == PlayerState.paused ||
        player.state == PlayerState.stopped) {
      player.resume();
    } else if (player.state == PlayerState.completed) {
      // Download status
      if (result[1] == 'true') {
        player.play(DeviceFileSource(
            '/data/user/0/com.liquidhive.openair/app_flutter/downloads/${result[0]}')); // MP3 Name
      } else {
        player.play(UrlSource(episodeItem.rssItem!.enclosure!.url!));
      }
    }

    episodeItem.setPlayingStatus = PlayingStatus.playing;

    audioState = 'Play';
    loadState = 'Play';
    updatePlaybackBar();

    selectedEpisode = episodeItem;
    notifyListeners();
  }

  Future<void> playerPauseButtonClicked() async {
    audioState = 'Pause';
    loadState = 'Detail';

    if (player.state == PlayerState.playing) {
      await player.pause();
    }

    selectedEpisode!.setPlayingStatus = PlayingStatus.paused;

    notifyListeners();
  }

  void fastForwardButtonClicked() {
    // TODO: Needs to check if the podcast is at the end

    if (podcastPosition.inSeconds + 10 < podcastDuration.inSeconds) {
      player.seek(Duration(seconds: podcastPosition.inSeconds + 10));
    }
  }

  void audioSpeedButtonClicked() {
    int index = audioSpeedOptions.indexOf(audioSpeedButtonLabel);
    int newIndex = (index + 1) % audioSpeedOptions.length;
    audioSpeedButtonLabel = audioSpeedOptions[newIndex];
    player.setPlaybackRate(double.parse(audioSpeedButtonLabel.substring(0, 3)));
    notifyListeners();
  }

  void updatePlaybackBar() {
    // player.getDuration().then((Duration? value) {
    //   podcastDuration = value;
    //   notifyListeners();
    // });

    podcastDuration = selectedEpisode!.getRssItem!.itunes!.duration!;
    notifyListeners();

    player.onPositionChanged.listen((Duration p) {
      podcastPosition = p;

      currentPlaybackPositionString =
          formatCurrentPlaybackPosition(podcastPosition);

      currentPlaybackRemainingTimeString =
          formatCurrentPlaybackRemainingTime(podcastPosition, podcastDuration);

      podcastCurrentPositionInMilliseconds =
          podcastPosition.inMilliseconds / podcastDuration.inMilliseconds;

      // debugPrint('Podcast Position: ${podcastPosition.inMilliseconds}');
      // debugPrint('Podcast Duration: ${podcastDuration.inMilliseconds}');
      // debugPrint('Current Position: $podcastCurrentPositionInMilliseconds');

      notifyListeners();
    });

    player.onPlayerStateChanged.listen((PlayerState playerState) {
      // TODO: Add marking podcast as completed automatically here
      if (playerState == PlayerState.completed) {
        debugPrint('Completed');
        audioState = 'Stop';
      }
    });

    notifyListeners();
  }

  String formatCurrentPlaybackPosition(Duration timeline) {
    int hours = timeline.inHours;
    int minutes = timeline.inMinutes;

    int seconds = timeline.inSeconds % 60;

    String result =
        "${hours != 0 ? hours < 10 ? '0$hours:' : '$hours:' : '00:'}${minutes != 0 ? minutes < 10 ? '0$minutes:' : '$minutes:' : '00:'}${seconds != 0 ? seconds < 10 ? '0$seconds' : '$seconds' : '00'}";

    return result;
  }

  String getPodcastDuration(EpisodeModel rssItem) {
    return "${rssItem.rssItem!.itunes!.duration!.inHours != 0 ? '${rssItem.rssItem!.itunes!.duration!.inHours} hr ' : ''}${rssItem.rssItem!.itunes!.duration!.inMinutes != 0 ? '${rssItem.rssItem!.itunes!.duration!.inMinutes} min' : ''}";
  }

  // TODO: This is the method that needs to be called when the pause button is pressed.
  String formatCurrentPlaybackRemainingTime(
    Duration timelinePosition,
    Duration timelineDuration,
  ) {
    int remainingSeconds =
        timelineDuration.inSeconds - timelinePosition.inSeconds;

    remainingSeconds = remainingSeconds > 0 ? remainingSeconds : 0;

    int remainingHours = Duration(seconds: remainingSeconds).inHours;
    int remainingMinutes = Duration(seconds: remainingSeconds).inMinutes % 60;
    int remainingSecondsAdjusted =
        Duration(seconds: remainingSeconds).inSeconds % 60;

    currentPodcastTimeRemaining =
        "${remainingHours != 0 ? '$remainingHours hr ' : ''}${remainingMinutes != 0 ? '$remainingMinutes min' : ''} left";

    String result =
        "${remainingHours != 0 ? remainingHours < 10 ? '0$remainingHours:' : '$remainingHours:' : '00:'}${remainingMinutes != 0 ? remainingMinutes < 10 ? '0$remainingMinutes:' : '$remainingMinutes:' : '00:'}${remainingSecondsAdjusted != 0 ? remainingSecondsAdjusted < 10 ? '0$remainingSecondsAdjusted' : '$remainingSecondsAdjusted' : '00'}";

    return result;
  }

  // TODO: Add playlist here

  Future<DownloadStatus> getDownloadStatus(String filename) async {
    if (await isMp3FileDownloaded(filename)) {
      return DownloadStatus.downloaded;
    }

    return DownloadStatus.notDownloaded;
  }

  Future<bool> isMp3FileDownloaded(String filename) async {
    final filePath = '${directory.path}/downloads/$filename';
    final file = File(filePath);
    return file.exists();
  }

  Future<String> getDownloadsPath(String filename) async {
    const storagePath = 'downloads'; // Assuming a downloads subdirectory

    // Create the downloads directory if it doesn't exist
    await Directory(path.join(directory.path, storagePath))
        .create(recursive: true);

    final absolutePath = path.joinAll([directory.path, storagePath, filename]);

    return absolutePath;
  }

  String formattedDownloadedPodcastName(String audioUrl) {
    String filename = path.basename(audioUrl); // Extract filename from URL

    int indexOfQuestionMark = filename.indexOf('?');

    if (indexOfQuestionMark != -1) {
      filename = filename.substring(0, indexOfQuestionMark);
    }

    return filename;
  }

  // TODO: Add playlist here

  Future<void> removeAllDownloadedPodcasts() async {
    Directory downloadsDirectory =
        Directory('/data/user/0/com.liquidhive.openair/app_flutter/downloads');
    List<FileSystemEntity> files = downloadsDirectory.listSync();

    for (FileSystemEntity file in files) {
      file.deleteSync();
    }

    // FIXME: Fix this
    // for (RssItemModel item in data) {
    //   if (item.downloaded == DownloadStatus.downloaded) {
    //     item.setDownloaded = DownloadStatus.notDownloaded;
    //   }
    // }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Removed all downloaded podcasts'),
      ),
    );

    notifyListeners();
  }

  // TODO: Needs to be multithreaded
  void playerDownloadButtonClicked(EpisodeModel item) async {
    item.setDownloaded = DownloadStatus.downloading;
    downloadingPodcasts.add(item.rssItem!.guid!);

    notifyListeners();

    final response = await http.get(Uri.parse(item.rssItem!.enclosure!.url!));

    if (response.statusCode == 200) {
      String filename =
          formattedDownloadedPodcastName(item.rssItem!.enclosure!.url!);

      final file = File(await getDownloadsPath(filename));

      await file.writeAsBytes(response.bodyBytes).whenComplete(
        () {
          item.setDownloaded = DownloadStatus.downloaded;
          downloadingPodcasts.remove(item..rssItem!.guid);
          notifyListeners();
        },
      );
    } else {
      throw Exception(
          'Failed to download podcast (Status Code: ${response.statusCode})');
    }
  }

  void playerRemoveDownloadButtonClicked(EpisodeModel item) async {
    Directory downloadsDirectory =
        Directory('/data/user/0/com.liquidhive.openair/app_flutter/downloads');
    List<FileSystemEntity> files = downloadsDirectory.listSync();

    String filename =
        formattedDownloadedPodcastName(item.rssItem!.enclosure!.url!);

    for (FileSystemEntity file in files) {
      if (path.basename(file.path) == filename) {
        file.deleteSync();
        break;
      }
    }

    item.downloaded = DownloadStatus.notDownloaded;

    Navigator.pop(context);
    notifyListeners();
  }

  // Update the main player slider position based on the slider value.
  void mainPlayerSliderClicked(double sliderValue) {
    player.seek(
      Duration(
        milliseconds: (sliderValue * podcastDuration.inMilliseconds).toInt(),
      ),
    );
    notifyListeners();
  }

  void mainPlayerRewindClicked() {}

  void mainPlayerFastForwardClicked() {}

  void mainPlayerPaybackSpeedClicked() {}

  void mainPlayerTimerClicked() {}

  void mainPlayerCastClicked() {}

  void mainPlayerMoreOptionsClicked() {}
}
