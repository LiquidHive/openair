import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/feed_model.dart';
import 'package:openair/providers/podcast_provider.dart';

import '../apis/api_service_provider.dart';

final feedFutureProvider = FutureProvider(
  (ref) async {
    Map<String, dynamic> feed =
        await ref.watch(apiServiceProvider).getPodcasts();

    ref.watch(podcastProvider).feed = feed;

    // TODO Make a variable in podcastProvider that allows a or statement to clear and refresh the list
    if (ref.read(podcastProvider).feedPodcasts.isEmpty) {
      for (Map<String, dynamic> podcast in feed['feeds']) {
        final FeedModel feedModel = FeedModel.fromJson(podcast);

        if (!ref.watch(podcastProvider).feedPodcasts.contains(feedModel)) {
          ref.watch(podcastProvider).feedPodcasts.add(feedModel);
        }
      }
    }

    return ref.watch(podcastProvider).feedPodcasts;
  },
);
