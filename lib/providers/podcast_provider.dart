import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:webfeed/webfeed.dart';

import 'package:openair/views/main_player.dart';

final podcastProvider = ChangeNotifierProvider<PodcastProvider>(
  (ref) {
    return PodcastProvider();
  },
);

enum DownloadStatus { downloaded, downloading, notDownloaded }

class PodcastProvider with ChangeNotifier {
  late AudioPlayer player;
  late StreamSubscription? mPlayerSubscription;

  late BuildContext context;

  late String podcastName;

  late String podcastTitle;
  late String podcastSubtitle;

  late int podcastTimeInHours;
  late int podcastTimeInMinutes;
  late int podcastTimeInSeconds;

  late String audioState;
  late String loadState; // Play, Load, Detail

  late Duration podcastPosition;
  late Duration podcastDuration;

  late double podcastCurrentPositionInMilliseconds;
  late String currentPlaybackPosition;
  late String currentPlaybackRemainingTime;

  late RssFeed _feed;
  late RssItem? _selectedItem;

  bool isSelectedRss = false;

  final String storagePath = 'openair/downloads';

  late Map<String, bool> downloadStatus;

  late Directory directory;

  int navIndex = 1;

  void setNavIndex(int navIndex) {
    this.navIndex = navIndex;
    notifyListeners();
  }

  /// Getters and setters are defined below.

  RssFeed? get feed => _feed;

  set feed(RssFeed? value) => _feed = value!;

  get selectedItem => _selectedItem;

  set setSelectedItem(RssItem rssItem) => _selectedItem = rssItem;

  Future<void> initial(
    BuildContext context,
  ) async {
    // removeAllDownloadedPodcasts();
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

    audioState = 'Pause';
    loadState = 'Detail'; // Play, Load, Detail

    downloadStatus = {};

    directory = await getApplicationDocumentsDirectory();
  }

  Future<void> removeAllDownloadedPodcasts() async {
    Directory downloadsDirectory =
        Directory('/data/user/0/com.liquidhive.openair/app_flutter/downloads');
    List<FileSystemEntity> files = downloadsDirectory.listSync();

    for (FileSystemEntity file in files) {
      if (file is File) {
        file.deleteSync();
      }
    }
  }

  Icon getDownloadIcon(DownloadStatus downloadStatus, bool isDownloaded) {
    Icon icon;

    if (isDownloaded) {
      icon = const Icon(Icons.downloading_rounded);
    } else {
      if (downloadStatus == DownloadStatus.notDownloaded) {
        icon = const Icon(Icons.download_rounded);
      } else {
        icon = const Icon(Icons.download_done_rounded);
      }
    }

    return icon;
  }

  // FIXME: This is not working
  Future<DownloadStatus> isPodcastDownloaded({
    required RssItem item,
  }) async {
    String mp3Name = formateDownloadedPodcastName(item.enclosure!.url!);
    bool isDownloaded = await isMp3FileDownloaded(mp3Name);

    if (isDownloaded) {
      return DownloadStatus.downloaded;
    } else {
      return DownloadStatus.notDownloaded;
    }
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

  // /data/user/0/com.liquidhive.openair/app_flutter/downloads/
  // VMP1366825685.mp3

  Future<List<String>> setPodcastStream(
    String? audioUrl,
    String? type,
  ) async {
    loadState = 'Load';

    String mp3Name = formateDownloadedPodcastName(audioUrl!);
    bool isDownloaded = await isMp3FileDownloaded(mp3Name);

    List<String> result = [mp3Name, isDownloaded.toString()];

    isDownloaded
        ? {
            await player.setSource(DeviceFileSource(
              audioUrl,
              mimeType: type,
            ))
          }
        : await player.setSource(UrlSource(
            audioUrl,
            mimeType: type,
          ));

    return result;
  }

  void playerPlayButtonClicked(
    RssItem rssItem,
  ) async {
    List<String> result = await setPodcastStream(
      rssItem.enclosure!.url,
      rssItem.enclosure!.type,
    );

    // todo Modify the play button in the card widget to be dynamic
    debugPrint('state: ${player.state}');
    debugPrint('isDownloaded: ${result[1]}');

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

    audioState = 'Play';
    loadState = 'Play';
    notifyListeners();
    updatePlaybackBar();

    setSelectedItem = rssItem;
    isSelectedRss = true;
    notifyListeners();
  }

  void updatePlaybackBar() {
    player.onDurationChanged.listen((Duration p) {
      podcastDuration = p;
      // todo I removed the notifyListeners(); here
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
        notifyListeners();
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

  String getPodcastDuration(RssItem rssItem) {
    return "${rssItem.itunes!.duration!.inHours != 0 ? '${rssItem.itunes!.duration!.inHours} hr ' : ''}${rssItem.itunes!.duration!.inMinutes != 0 ? '${rssItem.itunes!.duration!.inMinutes} min' : ''}";
  }

  String formatCurrentPlaybackRemainingTime(
      Duration timelinePosition, Duration timelineDuration) {
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

  DownloadStatus getDownloadStatus(String filename) {
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

    debugPrint('absolutePath: $absolutePath');

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

  void playerDownloadButtonClicked(RssItem item) async {
    debugPrint('Downloading podcast');

    final response = await http.get(Uri.parse(item.enclosure!.url!));
    debugPrint('Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      String filename = formateDownloadedPodcastName(item.enclosure!.url!);
      debugPrint('filename: $filename');

      final file = File(await getDownloadsPath(filename));

      await file.writeAsBytes(response.bodyBytes).whenComplete(
        () {
          debugPrint('Podcast downloaded successfully!');
          downloadStatus[filename] = true;
        },
      );

      notifyListeners();
    } else {
      throw Exception(
          'Failed to download podcast (Status Code: ${response.statusCode})');
    }
  }

  // todo sup

  Future<void> playerPauseButtonClicked() async {
    audioState = 'Pause';
    loadState = 'Detail';

    if (player.state == PlayerState.playing) {
      await player.pause();
    }

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
