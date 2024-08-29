import 'package:openair/providers/podcast_provider.dart';
import 'package:webfeed/domain/rss_item.dart';

class EpisodeModel {
  RssItem? rssItem;
  DownloadStatus? downloaded;
  PlayingStatus? playingStatus;

  EpisodeModel({
    required this.rssItem,
    required this.downloaded,
    this.playingStatus = PlayingStatus.detail,
  });

  RssItem? get getRssItem => rssItem;

  set setRssItem(rssItem) => this.rssItem = rssItem;

  DownloadStatus? get getDownloaded => downloaded;

  set setDownloaded(downloaded) => this.downloaded = downloaded;

  PlayingStatus? get getPlayingStatus => playingStatus;

  set setPlayingStatus(playingStatus) => this.playingStatus = playingStatus;
}
