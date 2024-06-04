import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/providers/podcast_provider.dart';

class MainPlayer extends ConsumerWidget {
  const MainPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          // Podcast artwork
          const Card(
            child: Column(),
          ),
          Image.network(
            height: 360.0,
            width: 360.0,
            'https://images.ctfassets.net/sfnkq8lmu5d7/4Ma58uke8SXDQLWYefWiIt/3f1945422ea07ea6520c7aae39180101/2021-11-24_Singleton_Puppy_Syndrome_One_Puppy_Litter.jpg?w=1000&h=750&q=70&fm=webp',
            // Replace with your podcast artwork URL
          ),
          // Episode title and description
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Episode Title',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.0),
              Text(
                'Episode Description',
              ),
            ],
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
                        // : ref.read(podcastProvider).playerPlayButtonClicked();
                        // TODO Change this
                        : Null;
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
          Row(
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
        ],
      ),
    );
  }
}
