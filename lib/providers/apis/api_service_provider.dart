import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:openair/api_keys.dart';

final apiServiceProvider = Provider(
  (ref) => ApiServiceProvider(),
);

class ApiServiceProvider {
  Future<Map<String, dynamic>> getPodcasts() async {
    var unixTime = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    String newUnixTime = unixTime.toString();

    var firstChunk = utf8.encode(ApiKeys.apiKey);
    var secondChunk = utf8.encode(ApiKeys.apiSecret);
    var thirdChunk = utf8.encode(newUnixTime);

    var output = AccumulatorSink<Digest>();
    var input = sha1.startChunkedConversion(output);
    input.add(firstChunk);
    input.add(secondChunk);
    input.add(thirdChunk);
    input.close();
    var digest = output.events.single;

    Map<String, String> headers = {
      "X-Auth-Date": newUnixTime,
      "X-Auth-Key": apiKey,
      "Authorization": digest.toString(),
      "User-Agent": "SomethingAwesome/1.0.1"
    };

    final response = await http.get(
        Uri.parse(
          'https://api.podcastindex.org/api/1.0/podcasts/trending?pretty&lang=en%2C+en-US',
        ),
        headers: headers);

    if (response.statusCode == 200) {
      final String xmlString = response.body;
      return json.decode(xmlString);
    } else {
      throw Exception('Failed to get data from the API');
    }
  }
}
