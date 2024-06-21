import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:webfeed/webfeed.dart';

final apiEpisodesProvider = Provider(
  (ref) {
    return ApiEpisodesProvider();
  },
);

class ApiEpisodesProvider {
  Future<RssFeed> getRssInfo(String podcastUrl) async {
    try {
      final Response res = await http.get(Uri.parse(podcastUrl));
      final String xmlString = res.body;

      return RssFeed.parse(xmlString);
    } catch (e) {
      throw Exception('Error getting podcasts: $e');
    }
  }
}
