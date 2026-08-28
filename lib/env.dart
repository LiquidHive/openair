import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
final class Env {
  @EnviedField(varName: 'PODCAST_INDEX_API_KEY', obfuscate: true)
  static String podcastIndexApiKey = _Env.podcastIndexApiKey;

  @EnviedField(varName: 'PODCAST_INDEX_API_SECRET', obfuscate: true)
  static String podcastIndexApiSecret = _Env.podcastIndexApiSecret;

  @EnviedField(varName: 'PODCAST_USER_AGENT', obfuscate: true)
  static String podcastUserAgent = _Env.podcastUserAgent;

  @EnviedField(varName: 'FYYD_ACCESS_TOKEN', obfuscate: true)
  static String fyydAccessToken = _Env.fyydAccessToken;

  @EnviedField(varName: 'PAYPAL_URL', obfuscate: true)
  static String paypalUrl = _Env.paypalUrl;

  @EnviedField(varName: 'DONATE_WITH_KOFI_URL', obfuscate: true)
  static String donateWithKofiUrl = _Env.donateWithKofiUrl;

  @EnviedField(varName: 'DISCORD_URL', obfuscate: true)
  static String discordUrl = _Env.discordUrl;

  @EnviedField(varName: 'URL_GITHUB_ISSUES', obfuscate: true)
  static String githubIssuesUrl = _Env.githubIssuesUrl;

  @EnviedField(varName: 'URL_GITHUB_DISCUSSION', obfuscate: true)
  static String githubDiscussionUrl = _Env.githubDiscussionUrl;

  @EnviedField(varName: 'PRIVACY_POLICY', obfuscate: true)
  static String privacyPolicy = _Env.privacyPolicy;

  @EnviedField(varName: 'URL_GITHUB', obfuscate: true)
  static String githubUrl = _Env.githubUrl;

  @EnviedField(varName: 'TERMS_OF_SERVICE', obfuscate: true)
  static String termsOfService = _Env.termsOfService;
}
