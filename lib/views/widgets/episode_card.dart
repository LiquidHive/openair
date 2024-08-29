import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/episode_model.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:openair/views/player/episode_detail.dart';
import 'package:openair/views/widgets/play_button_widget.dart';

class EpisodeCard extends ConsumerWidget {
  final EpisodeModel episodeItem;

  const EpisodeCard({
    super.key,
    required this.episodeItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(podcastProvider).selectedEpisode = episodeItem;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EpisodeDetail(
              episodeItem: episodeItem,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
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
                              ref.watch(podcastProvider).selectedPodcast!.artwork,
                            ),
                            fit: BoxFit.cover,
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
                            ref.watch(podcastProvider).selectedPodcast!.title,
                            softWrap: true,
                            style: const TextStyle(
                              fontSize: 14.0,
                            ),
                          ),
                          Text(
                            '${episodeItem.rssItem!.pubDate!.day}/${episodeItem.rssItem!.pubDate!.month}/${episodeItem.rssItem!.pubDate!.year}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 40.0,
                  child: Text(
                    episodeItem.rssItem!.title!,
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 88.0,
                  child: Text(
                    episodeItem.rssItem!.description!,
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
                        onPressed: () {
                          if (episodeItem.playingStatus !=
                              PlayingStatus.playing) {
                            ref
                                .read(podcastProvider.notifier)
                                .playerPlayButtonClicked(
                                  episodeItem,
                                );
                          }
                        },
                        child: PlayButtonWidget(
                          episodeItem: episodeItem,
                        ),
                      ),
                    ),
                    // Playlist button
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.playlist_add_rounded),
                    ),
                    // Download button
                    IconButton(
                      onPressed: () {
                        if (episodeItem.getDownloaded ==
                            DownloadStatus.notDownloaded) {
                          ref
                              .read(podcastProvider.notifier)
                              .playerDownloadButtonClicked(episodeItem);
        
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Downloading \'${episodeItem.rssItem!.title}\''),
                            ),
                          );
                        } else if (episodeItem.getDownloaded ==
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
                                          episodeItem);
        
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Removed \'${episodeItem.rssItem!.title}\''),
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
                          .getDownloadIcon(episodeItem.getDownloaded!),
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
    );
  }
}
