import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/providers/parses/feed_future_provider.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:openair/views/widgets/discover_card.dart';

class ExplorePage extends ConsumerWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(feedFutureProvider.future),
        child: GridView.count(
          // TODO: Change the grid view count based on the screen size
          crossAxisCount: 2,
          mainAxisSpacing: 8.0,
          crossAxisSpacing: 8.0,
          childAspectRatio: 7.4,
          children: List.generate(
            ref.watch(podcastProvider).feedItems.length,
            (int index) => DiscoverCard(
              podcastItem: ref.watch(podcastProvider).feedItems[index],
            ),
          ),
        ),
      ),
    );
  }
}
