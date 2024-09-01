import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:openair/views/player/episode_detail.dart';

class MainPlayer extends ConsumerWidget {
  const MainPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const double imageSize = 300.0;

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EpisodeDetail(
                          episodeItem:
                              ref.watch(podcastProvider).selectedEpisode!,
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
                              ref
                                  .watch(podcastProvider)
                                  .selectedPodcast!
                                  .artwork,
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                        width: imageSize,
                        height: imageSize,
                      ),
                    ),
                  ),
                  Text(
                    ref.watch(podcastProvider).selectedEpisode!.rssItem!.title!,
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    ref
                            .watch(podcastProvider)
                            .selectedEpisode!
                            .rssItem!
                            .itunes!
                            .subtitle ??
                        '',
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
                        .watch(podcastProvider.notifier)
                        .podcastCurrentPositionInMilliseconds,
                    onChanged: (value) => ref
                        .watch(podcastProvider.notifier)
                        .mainPlayerSliderClicked(value),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ref
                              .read(podcastProvider.notifier)
                              .currentPlaybackPositionString,
                        ),
                        Text(
                          '-${ref.read(podcastProvider.notifier).currentPlaybackRemainingTimeString}',
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
                  // Rewind button
                  IconButton(
                    onPressed: () => ref
                        .read(podcastProvider.notifier)
                        .rewindButtonClicked(),
                    icon: const SizedBox(
                      width: 52.0,
                      height: 52.0,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.fast_rewind_rounded),
                          Positioned(
                            top: 30.0,
                            left: 25.0,
                            right: 0.0,
                            child: Icon(Icons.timer_10_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Play/pause button
                  IconButton(
                    onPressed: () async {
                      ref.watch(podcastProvider).audioState == 'Play'
                          ? ref
                              .read(podcastProvider.notifier)
                              .playerPauseButtonClicked()
                          : ref.read(podcastProvider).playerPlayButtonClicked(
                                ref.watch(podcastProvider).selectedEpisode!,
                              );
                    }, // Add play/pause functionality
                    icon: ref.watch(podcastProvider).audioState == 'Play'
                        ? const Icon(Icons.pause_rounded)
                        : const Icon(Icons.play_arrow_rounded),
                    iconSize: 48.0,
                  ),
                  // Fast forward button
                  IconButton(
                    onPressed: () => ref
                        .read(podcastProvider.notifier)
                        .fastForwardButtonClicked(),
                    icon: const SizedBox(
                      width: 52.0,
                      height: 52.0,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.fast_forward_rounded),
                          Positioned(
                            top: 30.0,
                            left: 25.0,
                            right: 0.0,
                            child: Icon(Icons.timer_10_rounded),
                          ),
                        ],
                      ),
                    ),
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
                  // Playback speed
                  TextButton(
                    onPressed: () => ref
                        .read(podcastProvider.notifier)
                        .audioSpeedButtonClicked(),
                    child: Text(
                      ref.watch(podcastProvider).audioSpeedButtonLabel,
                      style: const TextStyle(
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
      ),
    );
  }
}
