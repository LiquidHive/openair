import 'package:webfeed/domain/itunes/itunes.dart';
import 'package:webfeed/domain/rss_enclosure.dart';

class RssItemModel {
  late final String? name;
  late final String? organisation;
  late final String? publishedDuration;
  late final DateTime? publishedDate;
  late final String? title;
  late final String? description;
  late final String? audioDuration;
  late final bool? isDownloaded;
  late final Itunes? itunes;
  late final RssEnclosure? enclosure;

  RssItemModel({
    required this.name,
    required this.organisation,
    required this.publishedDuration,
    required this.publishedDate,
    required this.title,
    required this.description,
    required this.audioDuration,
    required this.isDownloaded,
    required this.itunes,
    required this.enclosure,
  });

  get getName => name;

  set setName(name) => name = name;

  get getOrganisation => organisation;

  set setOrganisation(organisation) => this.organisation = organisation;

  get getPublishedDuration => publishedDuration;

  set setPublishedDuration(publishedDuration) =>
      this.publishedDuration = publishedDuration;

  get getPublishedDate => publishedDate;

  set setPublishedDate(publishedDate) => this.publishedDate = publishedDate;

  get getEpisodeName => title;

  set setEpisodeName(title) => this.title = title;

  get getDescription => description;

  set setDescription(description) => this.description = description;

  get getAudioDuration => audioDuration;

  set setAudioDuration(audioDuration) => this.audioDuration = audioDuration;

  get getIsDownloaded => isDownloaded;

  set setIsDownloaded(isDownloaded) => this.isDownloaded = isDownloaded;

  get getItunes => itunes;

  set setItunes(itunes) => this.itunes = itunes;

  get getEnclosure => enclosure;

  set setEnclosure(enclosure) => this.enclosure = enclosure;
}
