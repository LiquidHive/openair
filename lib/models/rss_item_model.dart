import 'package:openair/providers/podcast_provider.dart';
import 'package:webfeed/domain/itunes/itunes.dart';
import 'package:webfeed/domain/rss_enclosure.dart';

class RssItemModel {
  String? guid;
  String? name;
  DateTime? publishedDate;
  String? title;
  String? description;
  String? subTitle;
  DownloadStatus? downloaded;
  PlayingStatus? playingStatus;
  Itunes? itunes;
  RssEnclosure? enclosure;

  RssItemModel({
    required this.guid,
    required this.name,
    required this.publishedDate,
    required this.title,
    required this.description,
    required this.subTitle,
    required this.downloaded,
    this.playingStatus = PlayingStatus.detail,
    required this.itunes,
    required this.enclosure,
  });

  get getGuid => guid;

  set setGuid(guid) => this.guid = guid;

  get getName => name;

  set setName(name) => this.name = name;

  get getPublishedDate => publishedDate;

  set setPublishedDate(publishedDate) => this.publishedDate = publishedDate;

  get getEpisodeName => title;

  set setEpisodeName(title) => this.title = title;

  get getDescription => description;

  set setDescription(description) => this.description = description;

  get getSubTitle => subTitle;

  set setSubTitle(subTitle) => this.subTitle = subTitle;

  get getDownloaded => downloaded;

  set setDownloaded(downloaded) => this.downloaded = downloaded;

  get getPlayingStatus => playingStatus;

  set setPlayingStatus(playingStatus) => this.playingStatus = playingStatus;

  get getItunes => itunes;

  set setItunes(itunes) => this.itunes = itunes;

  get getEnclosure => enclosure;

  set setEnclosure(enclosure) => this.enclosure = enclosure;
}
