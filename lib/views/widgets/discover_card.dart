import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/feed_model.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:openair/views/navPages/episodes_page.dart';

class DiscoverCard extends ConsumerWidget {
  final FeedModel podcastItem;

  const DiscoverCard({
    super.key,
    required this.podcastItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(podcastProvider.notifier).selectedPodcast = podcastItem;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const EpisodesPage(),
          ),
        );
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  image: DecorationImage(
                    image: NetworkImage(
                      podcastItem.artwork,
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
                width: 62.0,
                height: 62.0,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      podcastItem.title,
                      maxLines: 2,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 200.0,
                      child: Text(
                        podcastItem.author,
                        maxLines: 2,
                        style: const TextStyle(
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
