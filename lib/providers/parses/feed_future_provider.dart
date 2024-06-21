import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/feed_model.dart';
import 'package:openair/providers/podcast_provider.dart';

import '../apis/api_service_provider.dart';

final feedFutureProvider = FutureProvider(
  (ref) async {
    Map<String, dynamic> feed =
        await ref.watch(apiServiceProvider).getPodcasts();

    ref.watch(podcastProvider).feed = feed;

    for (Map<String, dynamic> podcast in feed['feeds']) {
      final FeedModel feedModel = FeedModel.fromJson(podcast);
      ref.watch(podcastProvider).feedItems.add(feedModel);
    }

    return ref.watch(podcastProvider).feedItems;
  },
);
