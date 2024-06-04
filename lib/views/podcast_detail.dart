import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/providers/podcast_provider.dart';

class PodcastDetail extends ConsumerWidget {
  const PodcastDetail({
    super.key,
  });

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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Image.network(
                      height: 62.0,
                      width: 62.0,
                      fit: BoxFit.contain,
                      ref.watch(podcastProvider).feed!.image!.url!,
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
                            fontSize: 18.0,
                          ),
                        ),
                        Text(
                          '${ref.watch(podcastProvider).selectedItem!.pubDate!.day}/${ref.watch(podcastProvider).selectedItem!.pubDate!.month}/${ref.watch(podcastProvider).selectedItem!.pubDate!.year}',
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
