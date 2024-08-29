import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/episode_model.dart';
import 'package:openair/providers/apis/api_episodes_provider.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:webfeed/webfeed.dart';

FutureProvider<List<EpisodeModel>> podcastEpisodesProvider = FutureProvider(
  (ref) async {
    final String podcastUrl =
        ref.watch(podcastProvider.notifier).selectedPodcast!.url;

    RssFeed feed = await ref.watch(apiEpisodesProvider).getRssInfo(podcastUrl);

    if (ref.watch(podcastProvider).episodeItems.isEmpty) {
      for (RssItem item in feed.items!) {
        String mp3Name = ref
            .watch(podcastProvider)
            .formattedDownloadedPodcastName(item.enclosure!.url!);

        DownloadStatus isDownloaded =
            await ref.watch(podcastProvider).getDownloadStatus(mp3Name);

        final EpisodeModel episode = EpisodeModel(
          rssItem: item,
          downloaded:
              ref.watch(podcastProvider).downloadingPodcasts.contains(item.guid)
                  ? DownloadStatus.downloading
                  : isDownloaded,
        );

        ref.watch(podcastProvider).episodeItems.add(episode);
      }
    }

    return ref.watch(podcastProvider).episodeItems;
  },
);
