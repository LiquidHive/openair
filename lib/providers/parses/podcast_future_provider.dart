import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/episode_model.dart';
import 'package:openair/providers/apis/api_episodes_provider.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:webfeed/webfeed.dart';

final podcastFutureProvider = FutureProvider.autoDispose(
  (ref) async {
    final String podcastUrl =
        ref.read(podcastProvider.notifier).selectedPodcast!.url;

    RssFeed feed = await ref.watch(apiEpisodesProvider).getRssInfo(podcastUrl);

    ref.watch(podcastProvider).episodeItems.clear();

    for (RssItem item in feed.items!) {
      String mp3Name = ref
          .read(podcastProvider)
          .formateDownloadedPodcastName(item.enclosure!.url!);

      DownloadStatus isDownloaded =
          await ref.read(podcastProvider).getDownloadStatus(mp3Name);

      final EpisodeModel episode = EpisodeModel(
        downloaded:
            ref.watch(podcastProvider).downloadingPodcasts.contains(item.guid)
                ? DownloadStatus.downloading
                : isDownloaded,
        rssItem: item,
      );

      ref.watch(podcastProvider).episodeItems.add(episode);
    }

    return ref.watch(podcastProvider).episodeItems;
  },
);
