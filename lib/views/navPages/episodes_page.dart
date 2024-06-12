import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/models/rss_item_model.dart';
import 'package:openair/providers/podcast_future_provider.dart';
import 'package:openair/providers/podcast_provider.dart';
import 'package:openair/views/widgets/card_widget.dart';

class EpisodesPage extends ConsumerWidget {
  const EpisodesPage({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(podcastFutureProvider.future),
      child: ListView(
        children: ref.watch(podcastProvider).data.map(
          (RssItemModel rssItem) {
            return CardWidget(
              rssItem: rssItem,
            );
          },
        ).toList(),
      ),
    );
  }
}
