class FeedModel {
  late int id;
  late String url;
  late String title;
  late String description;
  late String author;
  late String image;
  late String artwork;
  late dynamic newsItemPublishTime;
  late dynamic itunesId;
  late dynamic trendScore;
  late String language;
  late Map<String, dynamic> categories;

  int get getId => id;
  set setId(int value) => id = value;

  String get getUrl => url;
  set setUrl(String value) => url = value;

  String get getTitle => title;
  set setTitle(String value) => title = value;

  String get getDescription => description;
  set setDescription(String value) => description = value;

  String get getAuthor => author;
  set setAuthor(String value) => author = value;

  String get getImage => image;
  set setImage(String value) => image = value;

  String get getArtwork => artwork;
  set setArtwork(String value) => artwork = value;

  dynamic get getNewsItemPublishTime => newsItemPublishTime;
  set setNewsItemPublishTime(dynamic value) => newsItemPublishTime = value;

  dynamic get getItunesId => itunesId;
  set setItunesId(dynamic value) => itunesId = value;

  dynamic get getTrendScore => trendScore;
  set setTrendScore(dynamic value) => trendScore = value;

  String get getLanguage => language;
  set setLanguage(String value) => language = value;

  Map<String, dynamic> get getCategories => categories;
  set setCategories(Map<String, String> value) => categories = value;

  FeedModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    url = json['url'];
    title = json['title'];
    description = json['description'];
    author = json['author'];
    image = json['image'];
    artwork = json['artwork'];
    newsItemPublishTime = json['newesItemPublishTime'];
    itunesId = json['itunesId'];
    trendScore = json['trendScore'];
    language = json['language'];
    categories = json['categories'];
  }
}
