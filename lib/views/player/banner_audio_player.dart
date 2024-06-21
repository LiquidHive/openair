import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/providers/podcast_provider.dart';

class BannerAudioPlayer extends ConsumerWidget {
  const BannerAudioPlayer({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        return Column(
          children: [
            ListTile(
              minTileHeight: 68.0,
              onTap: () {
                ref.read(podcastProvider.notifier).bannerControllerClicked();
              },
              // FIXME: Aqui debe ser la imagen
              // leading: Container(
              //   decoration: BoxDecoration(
              //     borderRadius: BorderRadius.circular(10.0),
              //     image: DecorationImage(
              //       image: NetworkImage(
              //         ref.watch(podcastProvider).feed.image!.url!,
              //       ),
              //       fit: BoxFit.cover, // Adjust fit as needed
              //     ),
              //   ),
              //   width: 62.0,
              //   height: 62.0,
              // ),
              title: Text(
                ref.watch(podcastProvider).selectedItem!.rssItem!.title!,
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
            LinearProgressIndicator(
              value: ref
                  .read(podcastProvider.notifier)
                  .podcastCurrentPositionInMilliseconds,
            ),
          ],
        );
      },
    );
  }
}
