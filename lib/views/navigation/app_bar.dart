import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/providers/podcast_provider.dart';

AppBar appBar(WidgetRef ref) {
  return AppBar(
    elevation: 4.0,
    shadowColor: Colors.grey,
    title: const Center(
      child: Text(
        'OpenAir',
        textAlign: TextAlign.center,
      ),
    ),
    actions: [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: IconButton(
          onPressed: () {
            ref.read(podcastProvider).removeAllDownloadedPodcasts();
          },
          icon: const Icon(Icons.search),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 8.0, 0),
        child: IconButton(
          onPressed: () {
            // TODO: Running test here to bring up the banner player
            // ref.read(podcastProvider.notifier).isPodcastSelected = true;
            ref.read(podcastProvider.notifier).playerPauseButtonClicked();
          },
          icon: const Icon(Icons.person),
        ),
      ),
    ],
  );
}
