import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/rss_item_model.dart';
import 'package:openair/providers/podcast_future_provider.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:openair/views/navPages/episodes_page.dart';
import 'package:openair/views/navPages/explore_page.dart';
import 'package:openair/views/navPages/library_page.dart';
import 'package:openair/views/navigation/app_bar.dart';
import 'package:openair/views/navigation/main_nav_bar.dart';

import 'player/banner_audio_player.dart';

bool once = false;

class Home extends ConsumerWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (once == false) {
      ref.read(podcastProvider).initial(
            context,
          );
      once = true;
    }

    final podcastRef = ref.watch(podcastFutureProvider);

    return Scaffold(
      appBar: appBar(ref),
      drawer: const Drawer(),
      body: podcastRef.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: false,
        data: (List<RssItemModel> data) {
          ref.read(podcastProvider.notifier).data = data;

          final pages = List<Widget>.unmodifiable([
            const EpisodesPage(),
            const ExplorePage(),
            const LibraryPage(),
          ]);

          return pages[ref.watch(podcastProvider).navIndex];
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
        height: ref.watch(podcastProvider).isPodcastSelected ? 134.0 : 58.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            ref.watch(podcastProvider).isPodcastSelected
                ? const BannerAudioPlayer()
                : const SizedBox(),
            const SizedBox(height: 58.0, child: MainNavBar()),
          ],
        ),
      ),
    );
  }
}
