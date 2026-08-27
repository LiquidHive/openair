import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations_plus/flutter_localizations_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:share_plus/share_plus.dart';

import 'package:openair/config/config.dart';
import 'package:openair/controllers/subscription_controller.dart';
import 'package:openair/controllers/sync_controller.dart';
import 'package:openair/model/hive_models/download_model.dart';
import 'package:openair/model/hive_models/history_model.dart';
import 'package:openair/model/hive_models/podcast_model.dart';
import 'package:openair/model/hive_models/subscription_model.dart';
import 'package:openair/providers/audio_provider.dart';
import 'package:openair/providers/hive_provider.dart';
import 'package:openair/views/main_pages/episode_detail.dart';
import 'package:openair/views/main_pages/episodes_page.dart';
import 'package:path_provider/path_provider.dart';

final openAirProvider = ChangeNotifierProvider<OpenAirProvider>(
  (ref) => OpenAirProvider(ref),
);

class OpenAirProvider extends ChangeNotifier {
  late BuildContext context;

  final String storagePath = 'openair/downloads';

  Directory? directory;

  int navIndex = 1;

  late bool hasConnection;

  final Ref ref;

  OpenAirProvider(this.ref);

  HiveService get hiveService => ref.read(hiveServiceProvider);
  SyncController get syncController => ref.read(syncControllerProvider);
  AudioController get audioController => ref.read(audioProvider);
  SubscriptionController get subscriptionController =>
      ref.read(subscriptionControllerProvider);

  Future<void> initial(BuildContext context) async {
    if (!kIsWeb) {
      directory = await getApplicationDocumentsDirectory();
    }

    this.context = context;

    final hiveService = ref.read(hiveServiceProvider);
    if (context.mounted) await hiveService.initial(context);

    try {
      final List<ConnectivityResult> connectivityResult =
          await (Connectivity().checkConnectivity());

      if (connectivityResult.contains(ConnectivityResult.none)) {
        hasConnection = false;
      } else {
        hasConnection = true;
      }
    } catch (e) {
      debugPrint(e.toString());
      hasConnection = false;
    }

    automaticDownloadQueuedEpisodes();
  }

  Future<bool> getConnectionStatus() async {
    try {
      final List<ConnectivityResult> connectivityResult =
          await (Connectivity().checkConnectivity());

      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      } else {
        return true;
      }
    } catch (e) {
      debugPrint(e.toString());
      return false;
    }
  }

  void getConnectionStatusTriggered() {
    getConnectionStatus().then((value) {
      hasConnection = value;
      notifyListeners();
    });
  }

  void setNavIndex(int navIndex) {
    this.navIndex = navIndex;
    notifyListeners();
  }

  void automaticDownloadQueuedEpisodes() {
    if (downloadQueuedEpisodesConfig) {
      // Implementation delegated to audio controller
    }
  }

  Future<void> exportToDb(String path) async {
    await syncController.exportDatabase(path);
  }

  Future<void> importFromDb(File file) async {
    await syncController.importDatabase(file);
  }

  // Backward compatibility methods delegating to controllers

  Future<bool> isSubscribed(String podcastTitle) async {
    return await subscriptionController.checkSubscriptionStatus(podcastTitle);
  }

  Future<Map<String, SubscriptionModel>> getSubscriptions() async {
    final subs = await subscriptionController.fetchAllSubscriptions();
    return subs;
  }

  Future<String> getSubscriptionsCount(String title) async {
    return await subscriptionController.getEpisodeCount(title);
  }

  Future<String> getAccumulatedSubscriptionCount() async {
    return await subscriptionController.getTotalNewEpisodesCount();
  }

  Future<String> getFeedsCount() async {
    return await hiveService.feedsCount();
  }

  Future<int> getInboxCount() async {
    return await hiveService.getNewInboxCount();
  }

  Future<String> getQueueCount() async {
    return await hiveService.queueCount();
  }

  Future<int> getDownloadsCount() async {
    return await hiveService.downloadsCount();
  }

  Future getQueue() async {
    return await hiveService.getQueue();
  }

  Future<bool> isEpisodeNew(String guid) async {
    final result = await hiveService.getEpisode(guid);
    return result == null;
  }

  Future<List<Map>> getSubscribedEpisodes() async {
    return await hiveService.getEpisodes();
  }

  Future<List<DownloadModel>> getSortedDownloadedEpisodes() async {
    return await hiveService.getSortedDownloads();
  }

  Future<List<HistoryModel>> getSortedHistory() async {
    return await hiveService.getSortedHistory();
  }

  void shareEpisode(
    BuildContext context,
    Map<String, dynamic> episode,
    String podcastTitle,
  ) {
    final episodeTitle = episode['title'] ?? 'Episode';
    final enclosureUrl = episode['enclosureUrl'] ?? '';
    final description = episode['description'] ?? '';
    final episodeUrl = episode['feedUrl'] ?? enclosureUrl;
    final guid = episode['guid'] ?? enclosureUrl;

    // Generate deep link for the episode
    final deepLink = 'openair://episode/${Uri.encodeComponent(guid)}';

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    Translations.of(context).text('shareEpisode'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                // Copy Deep Link
                ListTile(
                  leading: const Icon(Icons.link_rounded),
                  title: Text(Translations.of(context).text('copyAppLink')),
                  subtitle: Text(
                      Translations.of(context).text('copyAppLinkSubtitle')),
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: deepLink),
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            Translations.of(context).text('appLinkCopied')),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                // Copy Episode Link
                ListTile(
                  leading: const Icon(Icons.link_rounded),
                  title: Text(Translations.of(context).text('copyEpisodeLink')),
                  subtitle: Text(
                      Translations.of(context).text('copyEpisodeLinkSubtitle')),
                  onTap: () {
                    if (episodeUrl.isNotEmpty) {
                      Clipboard.setData(
                        ClipboardData(text: episodeUrl),
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(Translations.of(context)
                              .text('episodeLinkCopied')),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                // Copy Episode Details
                ListTile(
                  leading: const Icon(Icons.info_rounded),
                  title:
                      Text(Translations.of(context).text('copyEpisodeDetails')),
                  onTap: () {
                    final shareText =
                        '$episodeTitle\n\nPodcast: $podcastTitle\n\n$description\n\n$deepLink';
                    Clipboard.setData(
                      ClipboardData(text: shareText),
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(Translations.of(context)
                            .text('episodeDetailsCopied')),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const Divider(height: 24),
                // Share via Native Share Sheet
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title:
                      Text(Translations.of(context).text('shareToSocialMedia')),
                  onTap: () {
                    final shareText =
                        'Check out "$episodeTitle" from $podcastTitle: $deepLink';
                    SharePlus.instance.share(ShareParams(text: shareText));
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> exportPodcastToOpml() async {}

  Future<void> openEpisodeByGuid(String guid, BuildContext context) async {
    try {
      final episode = await hiveService.getEpisode(guid);
      if (episode != null && context.mounted) {
        // Get podcast information from episode
        final podcastData = episode['podcast'] as Map<String, dynamic>?;
        if (podcastData != null) {
          final podcast = PodcastModel.fromJson(podcastData);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EpisodeDetail(
                episodeItem: Map<String, dynamic>.from(episode),
                podcast: podcast,
              ),
            ),
          );
        } else {
          debugPrint('Podcast data not found for episode');
        }
      } else {
        debugPrint('Episode not found with guid: $guid');
        if (context.mounted) {
          _showEpisodeNotFoundDialog(context, guid);
        }
      }
    } catch (e) {
      debugPrint('Error opening episode by guid: $e');
      if (context.mounted) {
        _showEpisodeNotFoundDialog(context, guid);
      }
    }
  }

  void _showEpisodeNotFoundDialog(BuildContext context, String guid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Episode Not Found'),
        content: Text(
          'This episode is not in your local database. You may need to subscribe to the podcast first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> openPodcastByFeedUrl(
      String feedUrl, BuildContext context) async {
    try {
      // Try to add the podcast by RSS URL
      final success =
          await audioController.addPodcastByRssUrl(feedUrl, context);

      if (success && context.mounted) {
        // Get the subscriptions to find the newly added podcast
        final subscriptions = await hiveService.getSubscriptions();
        final podcast = subscriptions.values
            .cast<SubscriptionModel>()
            .firstWhere(
              (sub) => sub.feedUrl == feedUrl,
              orElse: () => throw Exception('Podcast not found after adding'),
            );

        // Create a PodcastModel from the subscription
        final podcastModel = PodcastModel(
          id: podcast.id,
          title: podcast.title,
          author: podcast.author,
          feedUrl: podcast.feedUrl,
          imageUrl: podcast.imageUrl,
          description: podcast.description,
          artwork: podcast.artwork,
        );

        // Set as current podcast and navigate to episodes page
        audioController.currentPodcast = podcastModel;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EpisodesPage(podcast: podcastModel),
          ),
        );
      } else if (context.mounted) {
        _showPodcastNotFoundDialog(context, feedUrl);
      }
    } catch (e) {
      debugPrint('Error opening podcast by feedUrl: $e');
      if (context.mounted) {
        _showPodcastNotFoundDialog(context, feedUrl);
      }
    }
  }

  void _showPodcastNotFoundDialog(BuildContext context, String feedUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Podcast Not Found'),
        content: Text(
          'Could not open the podcast. The feed URL may be invalid or the podcast is not available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void downloadEnqueue(BuildContext context) async {
    // Implementation delegated to audio controller
  }

  Future<void> synchronize(BuildContext context) async {
    await syncController.synchronize(context);
  }

  String podcastLanguages(List<String> languages) {
    String lang = '';

    for (var i = 0; i < languages.length; i++) {
      lang += languages[i];
      if (i < languages.length - 1) {
        lang += ',';
      }
    }

    return lang;
  }
}

final getConnectionStatusProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final podcastIndexService = ref.read(openAirProvider);
  return await podcastIndexService.getConnectionStatus();
});
