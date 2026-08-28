import 'dart:io';

import 'dart:ui';

import 'package:openair/views/widgets/podcast_image.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations_plus/flutter_localizations_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openair/config/config.dart';
import 'package:openair/model/hive_models/subscription_model.dart';
import 'package:openair/providers/audio_provider.dart';
import 'package:openair/providers/hive_provider.dart';
import 'package:openair/providers/openair_provider.dart';

import 'package:openair/views/main_pages/episodes_page.dart';

class MainPlayer extends ConsumerStatefulWidget {
  const MainPlayer({super.key});

  @override
  MainPlayerState createState() => MainPlayerState();
}

class MainPlayerState extends ConsumerState<MainPlayer> {
  final double imageSize = 250.0;

  @override
  void initState() {
    super.initState();
    ref.read(audioProvider).updateAppContext(context);
  }

  double _artworkSize(BuildContext context) {
    final isWide = !Platform.isAndroid && !Platform.isIOS ||
        wideScreenMinWidth < MediaQuery.sizeOf(context).width;

    final screenWidth = MediaQuery.of(context).size.width;
    final maxSize = screenWidth * 0.8;
    return isWide ? maxSize.clamp(0, 280) : maxSize;
  }

  void _startSleepTimer(int minutes) {
    ref.read(audioProvider).startSleepTimer(minutes);
  }

  void _cancelSleepTimer() {
    ref.read(audioProvider).cancelSleepTimer();
  }

  String _formatRemainingTime(int? remainingSeconds) {
    if (remainingSeconds == null) return '';
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final audioState = ref.watch(audioProvider);

          Widget buildTimerOption(int minutes, String label) {
            final isActive = audioState.sleepTimerMinutes == minutes;
            final theme = Theme.of(context);
            return ListTile(
              title: Text(
                label,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? theme.colorScheme.primary : null,
                ),
              ),
              trailing: isActive
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _startSleepTimer(minutes);
              },
            );
          }

          return AlertDialog(
            title: Text(audioState.isSleepTimerActive
                ? '${Translations.of(context).text('sleepTimer')} (${_formatRemainingTime(audioState.remainingSeconds)})'
                : Translations.of(context).text('sleepTimer')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildTimerOption(15, '15 min'),
                buildTimerOption(30, '30 min'),
                buildTimerOption(45, '45 min'),
                buildTimerOption(60, '1 hour'),
                buildTimerOption(90, '90 min'),
                buildTimerOption(120, '2 hours'),
                if (audioState.isSleepTimerActive)
                  ListTile(
                    title: Text(
                      Translations.of(context).text('cancelTimer'),
                      style: const TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _cancelSleepTimer();
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showOptionsMenu(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> currentEpisode,
    dynamic audioState,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer(
        builder: (context, widgetRef, child) {
          return FutureBuilder<bool>(
            future: widgetRef
                .read(audioProvider)
                .isAudioDownloaded(currentEpisode['guid']),
            builder: (context, downloadSnapshot) {
              final isDownloaded = downloadSnapshot.data ?? false;

              return FutureBuilder<bool>(
                future: _isEpisodeCompleted(widgetRef, currentEpisode['guid']),
                builder: (context, completedSnapshot) {
                  return FutureBuilder<bool>(
                    future: _isEpisodeQueued(widgetRef, currentEpisode['guid']),
                    builder: (context, queuedSnapshot) {
                      final isQueued = queuedSnapshot.data ?? false;

                      return SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Episode description
                              ListTile(
                                leading: const Icon(Icons.description_outlined),
                                title: Text(Translations.of(context)
                                    .text('episodeDetails')),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showEpisodeDescription(
                                      context, currentEpisode);
                                },
                              ),
                              // Download/Remove
                              ListTile(
                                leading: Icon(
                                  isDownloaded
                                      ? Icons.download_done_rounded
                                      : Icons.download_rounded,
                                ),
                                title: Text(
                                  isDownloaded
                                      ? Translations.of(context)
                                          .text('removeDownload')
                                      : Translations.of(context)
                                          .text('downloadEpisode'),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  if (isDownloaded) {
                                    widgetRef
                                        .read(audioProvider)
                                        .removeDownload(currentEpisode);
                                  } else {
                                    widgetRef
                                        .read(audioProvider)
                                        .downloadEpisode(currentEpisode,
                                            audioState.currentPodcast, context);
                                  }
                                },
                              ),
                              // Add to queue/Remove from queue
                              ListTile(
                                leading: Icon(
                                  isQueued
                                      ? Icons.playlist_add_check_rounded
                                      : Icons.playlist_add_rounded,
                                ),
                                title: Text(
                                  isQueued
                                      ? Translations.of(context)
                                          .text('removeFromQueue')
                                      : Translations.of(context)
                                          .text('addToQueue'),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  if (isQueued) {
                                    widgetRef
                                        .read(audioProvider)
                                        .removeFromQueue(
                                            currentEpisode['guid']);
                                  } else {
                                    widgetRef.read(audioProvider).addToQueue(
                                        currentEpisode,
                                        audioState.currentPodcast,
                                        context);
                                  }
                                },
                              ),
                              // Go to podcast
                              ListTile(
                                leading: const Icon(Icons.album_rounded),
                                title: Text(Translations.of(context)
                                    .text('viewPodcast')),
                                onTap: () {
                                  Navigator.pop(context);
                                  if (audioState.currentPodcast != null) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => EpisodesPage(
                                          podcast: audioState.currentPodcast!,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<bool> _isEpisodeCompleted(WidgetRef ref, String guid) async {
    final hiveService = ref.read(hiveServiceProvider);
    final completed = await hiveService.getCompletedEpisodes();
    return completed.containsKey(guid);
  }

  Future<bool> _isEpisodeQueued(WidgetRef ref, String guid) async {
    final hiveService = ref.read(hiveServiceProvider);
    final queue = await hiveService.getQueue();
    return queue.containsKey(guid);
  }

  void _showEpisodeDescription(
    BuildContext context,
    Map<String, dynamic> episode,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                episode['title'] ?? 'Episode Details',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                episode['podcastTitle'] ?? episode['author'] ?? 'Unknown',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (episode['datePublished'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Published: ${_formatDate(episode['datePublished'])}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (episode['duration'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Duration: ${episode['duration']} minutes',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (episode['description'] != null &&
                    episode['description'].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      episode['description'] ?? '',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(dynamic dateValue) {
    try {
      if (dateValue is int) {
        final date = DateTime.fromMillisecondsSinceEpoch(dateValue * 1000);
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } else if (dateValue is String) {
        return dateValue;
      }
    } catch (e) {
      return 'Unknown date';
    }
    return 'Unknown date';
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioProvider);
    final currentEpisode = audioState.currentEpisode;
    final subsAsync = ref.watch(subscriptionsProvider);
    final favoriteListAsync = ref.watch(getFavoriteProvider);

    if (currentEpisode == null || currentEpisode.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    String getPodcastTitle(Map<String, dynamic> episode,
        AsyncValue<Map<String, SubscriptionModel>> subs) {
      if (episode['podcastTitle'] != null) return episode['podcastTitle'];
      return subs.when(
        data: (subsMap) {
          final podcastId = episode['podcastId'];
          if (podcastId != null) {
            for (final entry in subsMap.entries) {
              if (entry.value.id.toString() == podcastId.toString()) {
                return entry.value.title;
              }
            }
          }
          return episode['author']?.toString() ??
              Translations.of(context).text('unknown');
        },
        loading: () => episode['author']?.toString() ?? '',
        error: (_, __) =>
            episode['author']?.toString() ??
            Translations.of(context).text('unknown'),
      );
    }

    final podcastTitle = getPodcastTitle(currentEpisode, subsAsync);

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Show Banner',
            icon: const Icon(Icons.unfold_more_rounded),
            onPressed: () {
              ref.read(audioProvider).restoreBanner();
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {
              _showOptionsMenu(context, ref, currentEpisode, audioState);
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Blur background
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(color: Colors.transparent),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildPlayerContent(
                    context,
                    currentEpisode,
                    podcastTitle,
                    audioState,
                    theme,
                    subsAsync,
                    favoriteListAsync),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerContent(
    BuildContext context,
    Map<String, dynamic> currentEpisode,
    String podcastTitle,
    dynamic audioState,
    ThemeData theme,
    AsyncValue<Map<String, SubscriptionModel>> subsAsync,
    AsyncValue favoriteListAsync,
  ) {
    final isWide = !Platform.isAndroid && !Platform.isIOS ||
        wideScreenMinWidth < MediaQuery.sizeOf(context).width;

    final content = Column(
      mainAxisSize: isWide ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!isWide) const Spacer(),
        // Artwork with hero and image
        Hero(
          tag: 'player_art',
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: podcastImage(
                currentEpisode['feedImage'] ?? currentEpisode['image'] ?? '',
                width: _artworkSize(context),
                height: _artworkSize(context),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Title
        Text(
          currentEpisode['title'] ?? '',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        // Author with navigation
        GestureDetector(
          onTap: () {
            if (audioState.currentPodcast != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      EpisodesPage(podcast: audioState.currentPodcast!),
                ),
              );
            }
          },
          child: Text(
            podcastTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        // Seek Bar
        Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                  elevation: 0,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 14,
                ),
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor:
                    theme.colorScheme.primary.withValues(alpha: 0.3),
                thumbColor: theme.colorScheme.primary,
              ),
              child: Slider(
                min: 0.0,
                max: 1.0,
                value: audioState.podcastCurrentPositionInMilliseconds,
                onChanged: (value) => audioState.seekTo(value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    audioState.currentPlaybackPositionString,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    audioState.currentPlaybackDurationString ?? '00:00:00',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Main Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded, size: 36),
              onPressed: () => audioState.playPreviousEpisode(context),
            ),
            _buildControlButton(
                context, Icons.replay_10_rounded, () => audioState.rewind()),
            // Play/Pause button
            GestureDetector(
              onTap: () {
                audioState.audioState == 'Play'
                    ? audioState.playerPauseButtonClicked()
                    : audioState.playerResumeButtonClicked();
              },
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  audioState.audioState == 'Play'
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 48,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
            _buildControlButton(context, Icons.forward_10_rounded,
                () => audioState.fastForward()),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, size: 36),
              onPressed: () => audioState.playNextEpisode(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Bottom Tools
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TextButton(
              onPressed: () => audioState.cyclePlaybackSpeed(),
              child: Text(
                playbackSpeedConfig,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            IconButton(
              icon: audioState.isSleepTimerActive
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatRemainingTime(audioState.remainingSeconds),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary),
                        ),
                      ],
                    )
                  : const Icon(Icons.timer_outlined),
              tooltip: audioState.isSleepTimerActive
                  ? '${audioState.sleepTimerMinutes} min - Tap to change'
                  : Translations.of(context).text('sleepTimer'),
              onPressed: _showTimerDialog,
            ),
            favoriteListAsync.when(
              data: (favoriteList) {
                final isFavorite =
                    favoriteList.containsKey(currentEpisode['guid']);
                return IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border_rounded,
                    color: isFavorite ? Colors.red : null,
                  ),
                  onPressed: () {
                    if (isFavorite) {
                      ref.read(audioProvider).removeEpisodeFromFavorite(
                            currentEpisode['guid'],
                          );
                    } else if (audioState.currentPodcast != null) {
                      ref.read(audioProvider).addEpisodeToFavorite(
                            currentEpisode,
                            audioState.currentPodcast!,
                            author: currentEpisode['author'] ??
                                audioState.currentPodcast!.author,
                          );
                    }
                    ref.invalidate(getFavoriteProvider);
                  },
                );
              },
              loading: () => IconButton(
                icon: const Icon(Icons.favorite_border_rounded),
                onPressed: null,
              ),
              error: (_, __) => IconButton(
                icon: const Icon(Icons.favorite_border_rounded),
                onPressed: null,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: Translations.of(context).text('share'),
              onPressed: () {
                ref.read(openAirProvider).shareEpisode(
                      context,
                      currentEpisode,
                      podcastTitle,
                    );
              },
            ),
          ],
        ),
        if (!isWide) const Spacer(),
      ],
    );

    if (isWide) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildControlButton(
      BuildContext context, IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 32),
      onPressed: onTap,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
