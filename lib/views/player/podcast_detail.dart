import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/rss_item_model.dart';
import 'package:openair/providers/podcast_provider.dart';

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
                    child: Image.network(
                      height: 94.0,
                      width: 94.0,
                      fit: BoxFit.contain,
                      ref.watch(podcastProvider).feed.image!.url!,
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
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 1.0,
                        shape: const StadiumBorder(
                          side: BorderSide(
                            width: 1.0,
                          ),
                        ),
                      ),
                      onPressed: () {},
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
                                .getPodcastDuration(
                                    ref.watch(podcastProvider).selectedItem!),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.playlist_add),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.download_sharp),
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
