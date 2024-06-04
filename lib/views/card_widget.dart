import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:openair/views/podcast_detail.dart';
import 'package:webfeed/webfeed.dart';

final downloadingProvider = StateProvider<bool>((ref) => false);

class CardWidget extends ConsumerWidget {
  final RssItem rssItem;

  const CardWidget({
    super.key,
    required this.rssItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool isDownloadingProvider = ref.watch(downloadingProvider);

    return FutureBuilder(
        future: ref.watch(podcastProvider).isPodcastDownloaded(
              item: rssItem,
            ),
        builder:
            (BuildContext context, AsyncSnapshot<DownloadStatus> snapshot) {
          // if (!snapshot.hasData) {
          //   return const Center(child: CircularProgressIndicator());
          // }

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () {
                ref.read(podcastProvider).setSelectedItem = rssItem;

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PodcastDetail(),
                  ),
                );
              },
              child: Card(
                child: Container(
                  width: 500.0,
                  decoration: BoxDecoration(
                    border: Border.all(width: 1.0),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Image.network(
                                height: 62.0,
                                width: 62.0,
                                fit: BoxFit.contain,
                                ref.watch(podcastProvider).feed!.image!.url!,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref.watch(podcastProvider).podcastName,
                                    softWrap: true,
                                    style: const TextStyle(
                                      fontSize: 18.0,
                                    ),
                                  ),
                                  Text(
                                    '${rssItem.pubDate!.day}/${rssItem.pubDate!.month}/${rssItem.pubDate!.year}',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          rssItem.title!,
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            rssItem.description!,
                            maxLines: 4,
                            style: const TextStyle(
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Play button
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                elevation: 1.0,
                                shape: const StadiumBorder(
                                  side: BorderSide(
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              onPressed: () => ref
                                  .read(podcastProvider.notifier)
                                  .playerPlayButtonClicked(
                                    rssItem,
                                  ),
                              child: Row(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 5.0,
                                    ),
                                    child: Icon(Icons.play_arrow_rounded),
                                  ),
                                  Text(
                                    ref
                                        .read(podcastProvider.notifier)
                                        .getPodcastDuration(rssItem),
                                  ),
                                ],
                              ),
                            ),
                            // Playlist button
                            IconButton(
                              onPressed: () {},
                              icon:
                                  const Icon(Icons.playlist_add_check_rounded),
                            ),
                            // Download button
                            IconButton(
                              onPressed: () {
                                if (snapshot.data !=
                                    DownloadStatus.downloaded) {
                                  // FIXME: Does not change the download icon to the downloading icon
                                  ref.read(downloadingProvider.notifier).state =
                                      true;

                                  ref
                                      .read(podcastProvider.notifier)
                                      .playerDownloadButtonClicked(rssItem);

                                  ref.read(downloadingProvider.notifier).state =
                                      false;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Downloading \'${rssItem.title}\''),
                                    ),
                                  );
                                } else {
                                  // TODO: Add remove download method here
                                }
                              },
                              icon: isDownloadingProvider
                                  ? const Icon(Icons.downloading_rounded)
                                  : ref
                                      .read(podcastProvider.notifier)
                                      .getDownloadIcon(
                                        snapshot.data!,
                                        isDownloadingProvider,
                                      ),
                              // const Icon(
                              // ? Icons.download_for_offline_rounded :
                              //   Icons.download_rounded,
                              // ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.more_vert_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        });
  }
}
