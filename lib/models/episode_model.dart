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

  get getRssItem => rssItem;

  set setRssItem(rssItem) => this.rssItem = rssItem;

  get getDownloaded => downloaded;

  set setDownloaded(downloaded) => this.downloaded = downloaded;

  get getPlayingStatus => playingStatus;

  set setPlayingStatus(playingStatus) => this.playingStatus = playingStatus;
}
