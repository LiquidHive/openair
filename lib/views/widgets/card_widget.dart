import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/rss_item_model.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:openair/views/player/podcast_detail.dart';
import 'package:openair/views/widgets/play_button_widget.dart';

class CardWidget extends ConsumerWidget {
  final RssItemModel rssItem;

  const CardWidget({
    super.key,
    required this.rssItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () {
          ref.read(podcastProvider).selectedItem = rssItem;

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PodcastDetail(
                rssItem: rssItem,
              ),
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
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            image: DecorationImage(
                              image: NetworkImage(
                                ref.watch(podcastProvider).feed.image!.url!,
                              ),
                              fit: BoxFit.cover, // Adjust fit as needed
                            ),
                          ),
                          width: 62.0,
                          height: 62.0,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref.watch(podcastProvider).podcastName,
                              softWrap: true,
                              style: const TextStyle(
                                fontSize: 14.0,
                              ),
                            ),
                            Text(
                              '${rssItem.publishedDate!.day}/${rssItem.publishedDate!.month}/${rssItem.publishedDate!.year}',
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
                      SizedBox(
                        width: 200.0,
                        child: ElevatedButton(
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
                          child: PlayButtonWidget(
                            rssItem: rssItem,
                          ),
                        ),
                      ),
                      // Playlist button
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.playlist_add_check_rounded),
                      ),
                      // Download button
                      IconButton(
                        onPressed: () {
                          if (rssItem.getDownloaded ==
                              DownloadStatus.notDownloaded) {
                            ref
                                .read(podcastProvider.notifier)
                                .playerDownloadButtonClicked(rssItem);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Downloading \'${rssItem.title}\''),
                              ),
                            );
                          } else if (rssItem.getDownloaded ==
                              DownloadStatus.downloaded) {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => SizedBox(
                                width: double.infinity,
                                height: 50.0,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(podcastProvider.notifier)
                                        .playerRemoveDownloadButtonClicked(
                                            rssItem);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Removed \'${rssItem.title}\''),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Remove download'),
                                ),
                              ),
                            );
                          } else {
                            // TODO: Add cancel download
                          }
                        },
                        icon: ref
                            .read(podcastProvider.notifier)
                            .getDownloadIcon(rssItem.getDownloaded!),
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
  }
}
