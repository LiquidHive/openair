import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/episode_model.dart';
import 'package:openair/providers/parses/podcast_future_provider.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:openair/views/navigation/app_bar.dart';
import 'package:openair/views/player/banner_audio_player.dart';
import 'package:openair/views/widgets/episode_card.dart';

class EpisodesPage extends ConsumerWidget {
  const EpisodesPage({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodesRef = ref.watch(podcastEpisodesProvider);

    return Scaffold(
      appBar: appBar(ref),
      body: episodesRef.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: false,
        data: (List<EpisodeModel> data) {
          return const EpisodesList();
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
      bottomNavigationBar: SizedBox(
        height: ref.watch(podcastProvider).isPodcastSelected ? 80.0 : 0.0,
        child: ref.watch(podcastProvider).isPodcastSelected
            ? const BannerAudioPlayer()
            : const SizedBox(),
      ),
    );
  }
}

class EpisodesList extends ConsumerWidget {
  const EpisodesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: RefreshIndicator(
          onRefresh: () => ref.refresh(podcastEpisodesProvider.future),
          child: ListView.builder(
            itemBuilder: (context, index) => EpisodeCard(
              episodeItem: ref.watch(podcastProvider).episodeItems[index],
            ),
          )),
    );
  }
}
