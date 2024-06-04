import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/providers/podcast_provider.dart';

class BannerAudioControllerWidget extends ConsumerWidget {
  const BannerAudioControllerWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        return Stack(
          children: [
            SizedBox(
              height: 68.0,
              child: ListTile(
                titleAlignment: ListTileTitleAlignment.top,
                onTap: () {
                  debugPrint('Tap Tap!');
                },
                // ref.read(podcastProvider.notifier).bannerControllerClicked,
                // leading: Image.network(
                //   height: 48.0,
                //   width: 48.0,
                //   fit: BoxFit.contain,
                //   ref.watch(podcastProvider).feed!.image!.url!,
                // ),
                title: Text(
                  ref.watch(podcastProvider).isSelectedRss != false
                      ? ref.watch(podcastProvider).selectedItem!.title
                      : 'Podcast Name',
                  style: const TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: IconButton(
                  onPressed: () {
                    ref.watch(podcastProvider).audioState == 'Play'
                        ? ref
                            .read(podcastProvider.notifier)
                            .playerPauseButtonClicked()
                        : ref
                            .read(podcastProvider.notifier)
                            .playerPlayButtonClicked(
                              ref.watch(podcastProvider).selectedItem!,
                            );
                  },
                  icon: ref.watch(podcastProvider).audioState == 'Play'
                      ? const Icon(Icons.pause_rounded)
                      : const Icon(Icons.play_arrow_rounded),
                ),
              ),
            ),
            // FIXME: Here we need to pass the podcast item
            // Positioned(
            //   bottom: 0.0,
            //   left: 0,
            //   right: 0,
            //   child: LinearProgressIndicator(
            //     value: ref
            //         .read(podcastProvider.notifier)
            //         .podcastCurrentPositionInMilliseconds,
            //     minHeight: 8.0,
            //   ),
            // ),
          ],
        );
      },
    );
  }
}
