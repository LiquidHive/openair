import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:webfeed/domain/rss_feed.dart';

final apiServiceProvider = Provider(
  (ref) => ApiService(),
);

class ApiService {
  // late String rssSource = 'https://itsallwidgets.com/podcast/feed';

  // M.K.B.H.D
  late String rssSource = 'https://feeds.megaphone.fm/STU4418364045';

  // Crime Junkie
  // late String rssSource = 'https://feeds.megaphone.fm/ADL9840290619';

  // late String rssSource = 'https://joeroganexp.libsyn.com/rss';

  Future<RssFeed> getPodcasts() async {
    try {
      final Response res = await http.get(Uri.parse(rssSource));
      final String xmlString = res.body;

      return RssFeed.parse(xmlString);
    } catch (e) {
      throw Exception('Error getting podcasts: $e');
    }
  }
}
