import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/rss_item_model.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:webfeed/webfeed.dart';

import 'api_service_provider.dart';

final podcastFutureProvider = FutureProvider(
  (ref) async {
    RssFeed feed = await ref.watch(apiServiceProvider).getPodcasts();
    ref.watch(podcastProvider).feed = feed;

    ref.watch(podcastProvider).podcastName = feed.title!;

    for (var item in feed.items!) {
      String mp3Name = ref
          .read(podcastProvider)
          .formateDownloadedPodcastName(item.enclosure!.url!);

      DownloadStatus isDownloaded =
          await ref.read(podcastProvider).getDownloadStatus(mp3Name);

      final RssItemModel itemModel = RssItemModel(
        guid: item.guid,
        name: item.title,
        publishedDate: item.pubDate!,
        title: item.title!,
        description: item.description!,
        subTitle: item.itunes!.subtitle!,
        downloaded:
            ref.watch(podcastProvider).downloadingPodcasts.contains(item.guid)
                ? DownloadStatus.downloading
                : isDownloaded,
        itunes: item.itunes!,
        enclosure: item.enclosure!,
      );

      ref.watch(podcastProvider).items.add(itemModel);
    }

    return ref.watch(podcastProvider).items;
  },
);
