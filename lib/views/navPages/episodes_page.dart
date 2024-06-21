import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/episode_model.dart';
import 'package:openair/providers/parses/podcast_future_provider.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:openair/views/navigation/app_bar.dart';
import 'package:openair/views/widgets/episode_card.dart';

class EpisodesPage extends ConsumerWidget {
  const EpisodesPage({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FIXME Does not update episodesRef on podcast change
    final episodesRef = ref.watch(podcastFutureProvider);

    return Scaffold(
      appBar: appBar(ref),
      drawer: const Drawer(),
      body: episodesRef.when(
        skipLoadingOnReload: false,
        skipLoadingOnRefresh: false,
        data: (List<EpisodeModel> data) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(podcastFutureProvider.future),
              child: GridView.count(
                // TODO: Change the grid view count based on the screen size
                crossAxisCount: 2,
                mainAxisSpacing: 8.0,
                crossAxisSpacing: 8.0,
                childAspectRatio: 2.2,
                children: List.generate(
                  ref.watch(podcastProvider).episodeItems.length,
                  (int index) {
                    return EpisodeCard(
                      episodeItem: data[index],
                    );
                  },
                ),
              ),
            ),
          );
        },
        error: (error, stackTrace) {
          return Text(error.toString());
        },
        loading: () {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}
