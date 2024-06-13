import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/rss_item_model.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:openair/views/widgets/play_button_widget.dart';

class PodcastDetail extends ConsumerWidget {
  const PodcastDetail({
    super.key,
    this.rssItem,
  });

  final RssItemModel? rssItem;

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
                            ref.watch(podcastProvider).feed.image!.url!,
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
                          ref.watch(podcastProvider).podcastName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 26.0,
                          ),
                        ),
                        Text(
                          '${ref.watch(podcastProvider).selectedItem!.getPublishedDate!.day}/${ref.watch(podcastProvider).selectedItem!.getPublishedDate!.month}/${ref.watch(podcastProvider).selectedItem!.getPublishedDate!.year}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                ref.watch(podcastProvider).selectedItem!.title!,
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
                        onPressed: () => ref
                            .read(podcastProvider.notifier)
                            .playerPlayButtonClicked(
                              rssItem!,
                            ),
                        child: PlayButtonWidget(
                          rssItem: rssItem!,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.playlist_add),
                    ),
                    IconButton(
                      onPressed: () {
                        if (rssItem!.getDownloaded ==
                            DownloadStatus.notDownloaded) {
                          ref
                              .read(podcastProvider.notifier)
                              .playerDownloadButtonClicked(rssItem!);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Downloading \'${rssItem!.title}\''),
                            ),
                          );
                        } else if (rssItem!.getDownloaded ==
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
                                          rssItem!);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Removed \'${rssItem!.title}\''),
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
                          .getDownloadIcon(rssItem!.getDownloaded!),
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
                child: Column(
                  children: [
                    Text(
                      ref.watch(podcastProvider).selectedItem!.description!,
                      style: const TextStyle(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
