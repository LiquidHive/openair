import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/views/card_widget.dart';
import 'package:webfeed/webfeed.dart';

class EpisodesPage extends ConsumerWidget {
  const EpisodesPage({
    super.key,
    required this.data,
  });

  final RssFeed data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: data.items!.map(
        (RssItem rssItem) {
          return CardWidget(
            rssItem: rssItem,
          );
        },
      ).toList(),
    );
  }
}
