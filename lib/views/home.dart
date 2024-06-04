import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/providers/api_service_provider.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:openair/views/app_bar.dart';
import 'package:openair/views/main_nav_bar.dart';
import 'package:openair/views/navPages/episodes_page.dart';
import 'package:openair/views/navPages/explore_page.dart';
import 'package:openair/views/navPages/library_page.dart';
import 'package:webfeed/webfeed.dart';

import 'banner_audio_controller_widget.dart';

final podcastFutureProvider = FutureProvider(
  (ref) async {
    List<RssItem> items = [];

    final Future<RssFeed> apiService =
        ref.watch(apiServiceProvider).getPodcasts().then(
      (value) {
        for (var item in value.items!) {
          items.add(item);
        }
      },
    );

    return apiService;
  },
);

class Home extends ConsumerWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcastRef = ref.watch(podcastFutureProvider);
    ref.read(podcastProvider).initial(context);

    return podcastRef.when(
      data: (RssFeed data) {
        final pages = List<Widget>.unmodifiable([
          EpisodesPage(data: data),
          const ExplorePage(),
          const LibraryPage(),
        ]);

        ref.watch(podcastProvider).feed = data;
        ref.watch(podcastProvider).podcastName = data.title!;

        return Scaffold(
          appBar: appBar(),
          drawer: const Drawer(),
          body: pages[ref.watch(podcastProvider).navIndex],
          persistentFooterButtons: const [
            BannerAudioControllerWidget(),
          ],
          bottomNavigationBar: const MainNavBar(),
        );
      },
      error: (error, stackTrace) {
        return Text(error.toString());
      },
      loading: () {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }
}
