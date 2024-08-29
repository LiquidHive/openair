import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/episode_model.dart';
import 'package:openair/providers/podcast_provider.dart';

class PlayButtonWidget extends ConsumerWidget {
  const PlayButtonWidget({
    super.key,
    required this.episodeItem,
  });

  final EpisodeModel episodeItem;

  // Three states: Detail, buffering, and playing

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const double paddingSpace = 8.0;

    PlayingStatus playStatus = episodeItem.playingStatus!;

    if (playStatus case PlayingStatus.detail) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: paddingSpace,
            ),
            child: Icon(Icons.play_arrow_rounded),
          ),
          Text(
            ref.watch(podcastProvider).getPodcastDuration(episodeItem),
          ),
        ],
      );
    } else if (playStatus case PlayingStatus.paused) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: paddingSpace,
            ),
            child: Icon(Icons.timelapse_rounded),
          ),
          Text(
            ref.watch(podcastProvider).currentPodcastTimeRemaining!,
          ),
        ],
      );
    } else if (playStatus case PlayingStatus.buffering) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 35.0,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: paddingSpace,
              ),
              child: LinearProgressIndicator(),
            ),
          ),
          Text('Buffering'),
        ],
      );
    }

    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: paddingSpace,
          ),
          child: Icon(Icons.stream_rounded),
        ),
        Text('Playing'),
      ],
    );
  }
}
