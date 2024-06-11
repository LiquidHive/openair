import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:openair/views/player/podcast_detail.dart';

class MainPlayer extends ConsumerWidget {
  const MainPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          // Podcast artwork

          // Episode title and description
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PodcastDetail(
                        rssItem: ref.watch(podcastProvider).selectedItem!,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(35.0),
                        image: DecorationImage(
                          image: NetworkImage(
                            ref.watch(podcastProvider).feed.image!.url!,
                          ),
                          fit: BoxFit.cover, // Adjust fit as needed
                        ),
                      ),
                      width: 512.0,
                      height: 512.0,
                    ),
                  ),
                ),
                Text(
                  ref.watch(podcastProvider).selectedItem!.title!,
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  ref.watch(podcastProvider).selectedItem!.subTitle!,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Column(
              children: [
                Slider(
                  value: ref
                      .watch(podcastProvider)
                      .podcastCurrentPositionInMilliseconds,
                  onChanged: (value) =>
                      // TODO: Add slider functionality
                      // ref.read(podcastProvider).mainPlayerSliderClicked(value),
                      0.0,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ref
                            .watch(podcastProvider.notifier)
                            .currentPlaybackPosition,
                      ),
                      Text(
                        '-${ref.watch(podcastProvider.notifier).currentPlaybackRemainingTime}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Playback controls
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () => {}, // Add rewind functionality
                  icon: const Icon(Icons.fast_rewind_rounded),
                ),
                IconButton(
                  onPressed: () async {
                    ref.watch(podcastProvider).audioState == 'Play'
                        ? ref
                            .read(podcastProvider.notifier)
                            .playerPauseButtonClicked()
                        : ref.read(podcastProvider).playerPlayButtonClicked(
                              ref.watch(podcastProvider).selectedItem!,
                            );
                  }, // Add play/pause functionality
                  icon: ref.watch(podcastProvider).audioState == 'Play'
                      ? const Icon(Icons.pause_rounded)
                      : const Icon(Icons.play_arrow_rounded),
                  iconSize: 48.0,
                ),
                IconButton(
                  onPressed: () => {}, // Add fast-forward functionality
                  icon: const Icon(Icons.fast_forward_rounded),
                ),
              ],
            ),
          ),
          // Slider for progress bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    '1.0x',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => {}, // Add fast-forward functionality
                  icon: const Icon(Icons.timer_outlined),
                ),
                IconButton(
                  onPressed: () => {}, // Add fast-forward functionality
                  icon: const Icon(Icons.cast),
                ),
                IconButton(
                  onPressed: () => {}, // Add fast-forward functionality
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
