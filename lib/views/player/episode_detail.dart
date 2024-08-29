import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/episode_model.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:openair/views/player/banner_audio_player.dart';
import 'package:openair/views/widgets/play_button_widget.dart';

class EpisodeDetail extends ConsumerWidget {
  const EpisodeDetail({
    super.key,
    this.episodeItem,
  });

  final EpisodeModel? episodeItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 15.0,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      width: 92.0,
                      height: 92.0,
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 26.0,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${ref.watch(podcastProvider).selectedEpisode!.rssItem!.pubDate!.day}/${ref.watch(podcastProvider).selectedEpisode!.rssItem!.pubDate!.month}/${ref.watch(podcastProvider).selectedEpisode!.rssItem!.pubDate!.year}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                ref.watch(podcastProvider).selectedEpisode!.rssItem!.title!,
                textAlign: TextAlign.start,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
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
                        onPressed: () =>
                            ref.read(podcastProvider).playerPlayButtonClicked(
                                  episodeItem!,
                                ),
                        child: PlayButtonWidget(
                          episodeItem: episodeItem!,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.playlist_add),
                    ),
                    IconButton(
                      onPressed: () {
                        if (episodeItem!.getDownloaded ==
                            DownloadStatus.notDownloaded) {
                          ref
                              .read(podcastProvider)
                              .playerDownloadButtonClicked(episodeItem!);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Downloading \'${episodeItem!.rssItem!.title}\''),
                            ),
                          );
                        } else if (episodeItem!.getDownloaded ==
                            DownloadStatus.downloaded) {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => SizedBox(
                              width: double.infinity,
                              height: 50.0,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  ref
                                      .read(podcastProvider)
                                      .playerRemoveDownloadButtonClicked(
                                          episodeItem!);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Removed \'${episodeItem!.rssItem!.title}\''),
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
                          .read(podcastProvider)
                          .getDownloadIcon(episodeItem!.getDownloaded!),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_vert_outlined),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  ref
                      .watch(podcastProvider)
                      .selectedEpisode!
                      .rssItem!
                      .description!,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SizedBox(
        height: ref.watch(podcastProvider).isPodcastSelected ? 75.0 : 0.0,
        child: ref.watch(podcastProvider).isPodcastSelected
            ? const BannerAudioPlayer()
            : const SizedBox(),
      ),
    );
  }
}
