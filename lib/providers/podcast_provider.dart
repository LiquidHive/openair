import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:openair/models/rss_item_model.dart';
import 'package:openair/views/player/main_player.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:webfeed/domain/rss_feed.dart';

final podcastProvider = ChangeNotifierProvider<PodcastProvider>(
  (ref) {
    return PodcastProvider();
  },
);

enum DownloadStatus { downloaded, downloading, notDownloaded }

enum PlayingStatus { detail, buffering, playing }

// /data/user/0/com.liquidhive.openair/app_flutter/downloads/
// VMP1366825685.mp3

class PodcastProvider with ChangeNotifier {
  List<String> downloadingPodcasts = [];

  late RssFeed feed;

  late AudioPlayer player;
  late StreamSubscription? mPlayerSubscription;

  late BuildContext context;

  late String podcastName;

  late String podcastTitle;
  late String podcastSubtitle;

  late String audioState; // Play, Pause, Stop
  late String loadState; // Play, Load, Detail

  late Duration podcastPosition;
  late Duration podcastDuration;

  late double podcastCurrentPositionInMilliseconds;
  late String currentPlaybackPosition;
  late String currentPlaybackRemainingTime;

  // todo remove me
  // late RssFeed _feed;
  late RssItemModel? selectedItem;

  final String storagePath = 'openair/downloads';

  late Directory directory;

  int navIndex = 0;

  bool isPodcastSelected = false;

  List<RssItemModel> items = [];

  // todo remove me
  /// Getters and setters are defined below.

  // RssFeed? get feed => _feed;

  // set feed(RssFeed? value) => _feed = value!;

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
    currentPlaybackPosition = '00:00:00';
    currentPlaybackRemainingTime = '00:00:00';

    selectedItem = null;

    audioState = 'Pause';
    loadState = 'Detail'; // Play, Load, Detail

    directory = await getApplicationDocumentsDirectory();
  }

  void setNavIndex(int navIndex) {
    this.navIndex = navIndex;
    notifyListeners();
  }

  // todo testing purposes
  Future<void> removeAllDownloadedPodcasts() async {
    Directory downloadsDirectory =
        Directory('/data/user/0/com.liquidhive.openair/app_flutter/downloads');
    List<FileSystemEntity> files = downloadsDirectory.listSync();

    for (FileSystemEntity file in files) {
      if (file is File) {
        file.deleteSync();
      }
    }

    debugPrint('Removed all downloaded podcasts');
    downloadingPodcasts.clear();

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
    RssItemModel rssItem,
  ) async {
    loadState = 'Load';

    // ignore: prefer_conditional_assignment
    if (selectedItem == null) {
      selectedItem = rssItem;
    }

    if (rssItem != selectedItem) {
      selectedItem!.setPlayingStatus = PlayingStatus.detail;
    }

    rssItem.setPlayingStatus = PlayingStatus.buffering;
    notifyListeners();

    String mp3Name = formateDownloadedPodcastName(rssItem.enclosure!.url!);
    bool isDownloaded = await isMp3FileDownloaded(mp3Name);

    List<String> result = [mp3Name, isDownloaded.toString()];

    isDownloaded
        ? {
            await player.setSource(DeviceFileSource(
              rssItem.enclosure!.url!,
              mimeType: rssItem.enclosure!.type,
            ))
          }
        : await player.setSource(UrlSource(
            rssItem.enclosure!.url!,
            mimeType: rssItem.enclosure!.type,
          ));

    return result;
  }

  void setShowSelectedPodcast() {
    isPodcastSelected = true;
    notifyListeners();
  }

  void playerPlayButtonClicked(
    RssItemModel rssItem,
  ) async {
    List<String> result = await setPodcastStream(rssItem);

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
        player.play(UrlSource(rssItem.enclosure!.url!));
      }
    }

    rssItem.setPlayingStatus = PlayingStatus.playing;

    audioState = 'Play';
    loadState = 'Play';
    updatePlaybackBar();

    selectedItem = rssItem;
    notifyListeners();
  }

  void updatePlaybackBar() {
    player.getDuration().then((Duration? value) {
      podcastDuration = value!;
    });

    player.onPositionChanged.listen((Duration p) {
      podcastPosition = p;

      currentPlaybackPosition = formatCurrentPlaybackPosition(podcastPosition);

      currentPlaybackRemainingTime =
          formatCurrentPlaybackRemainingTime(podcastPosition, podcastDuration);

      podcastCurrentPositionInMilliseconds =
          podcastPosition.inMilliseconds / podcastDuration.inMilliseconds;

      notifyListeners();
    });

    player.onPlayerStateChanged.listen((PlayerState playerState) {
      debugPrint('Player state: ${playerState.toString()}');

      // TODO Add marking podcast as completed automatically here
      if (playerState == PlayerState.completed) {
        audioState = 'Stop';
      }
    });
  }

  String formatCurrentPlaybackPosition(Duration timeline) {
    int hours = timeline.inHours;
    int minutes = timeline.inMinutes;

    int seconds = timeline.inSeconds % 60;

    String result =
        "${hours != 0 ? hours < 10 ? '0$hours:' : '$hours:' : '00:'}${minutes != 0 ? minutes < 10 ? '0$minutes:' : '$minutes:' : '00:'}${seconds != 0 ? seconds < 10 ? '0$seconds' : '$seconds' : '00'}";

    return result;
  }

  String getPodcastDuration(RssItemModel rssItem) {
    return "${rssItem.itunes!.duration!.inHours != 0 ? '${rssItem.itunes!.duration!.inHours} hr ' : ''}${rssItem.itunes!.duration!.inMinutes != 0 ? '${rssItem.itunes!.duration!.inMinutes} min' : ''}";
  }

  String? displayPodcastAudioInfo(RssItemModel rssItem) {
    String? result;

    if (rssItem == selectedItem) {
      if (audioState == 'Pause') {
        result = '$currentPlaybackRemainingTime left';
      }
    } else {
      result = getPodcastDuration(rssItem);
    }

    return result!;
  }

  // todo this is the method that needs to be called when the pause button is pressed.
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

    String result =
        "${remainingHours != 0 ? remainingHours < 10 ? '0$remainingHours:' : '$remainingHours:' : '00:'}${remainingMinutes != 0 ? remainingMinutes < 10 ? '0$remainingMinutes:' : '$remainingMinutes:' : '00:'}${remainingSecondsAdjusted != 0 ? remainingSecondsAdjusted < 10 ? '0$remainingSecondsAdjusted' : '$remainingSecondsAdjusted' : '00'}";

    return result;
  }

  // FIXME add playlist here

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

  String formateDownloadedPodcastName(String audioUrl) {
    String filename = path.basename(audioUrl); // Extract filename from URL

    int indexOfQuestionMark = filename.indexOf('?');

    if (indexOfQuestionMark != -1) {
      filename = filename.substring(0, indexOfQuestionMark);
    }

    return filename;
  }

  // todo add playlist here

  void playerDownloadButtonClicked(RssItemModel item) async {
    item.setDownloaded = DownloadStatus.downloading;
    downloadingPodcasts.add(item.getGuid);

    notifyListeners();

    final response = await http.get(Uri.parse(item.enclosure!.url!));

    if (response.statusCode == 200) {
      String filename = formateDownloadedPodcastName(item.enclosure!.url!);

      final file = File(await getDownloadsPath(filename));

      await file.writeAsBytes(response.bodyBytes).whenComplete(
        () {
          item.setDownloaded = DownloadStatus.downloaded;
          downloadingPodcasts.remove(item.getGuid);
          notifyListeners();
        },
      );
    } else {
      throw Exception(
          'Failed to download podcast (Status Code: ${response.statusCode})');
    }
  }

  // todo when the podcast is pause, display the remaining time of the selected podcast
  // Show the remaining time of the podcast when 30 seconds has passed

  Future<void> playerPauseButtonClicked() async {
    audioState = 'Pause';
    loadState = 'Detail';

    if (player.state == PlayerState.playing) {
      await player.pause();
    }

    selectedItem!.setPlayingStatus = PlayingStatus.detail;

    notifyListeners();
  }

  void mainPlayerSliderClicked(double sliderValue) {
    debugPrint(sliderValue.toString());
  }

  void mainPlayerRewindClicked() {}

  void mainPlayerFastForwardClicked() {}

  void mainPlayerPaybackSpeedClicked() {}

  void mainPlayerTimerClicked() {}

  void mainPlayerCastClicked() {}

  void mainPlayerMoreOptionsClicked() {}
}
