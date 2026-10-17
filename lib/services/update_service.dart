import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'telemetry/telemetry_service.dart';

enum UpdateChannel { play, fdroid, github }

const buildUpdateChannel = appFlavor == 'play'
    ? UpdateChannel.play
    : String.fromEnvironment('UPDATE_CHANNEL') == 'github'
    ? UpdateChannel.github
    : UpdateChannel.fdroid;

class AvailableUpdate {
  final String? version;
  final Uri url;

  const AvailableUpdate({this.version, required this.url});
}

class UpdateService extends ChangeNotifier {
  static const packageName = 'com.moaymandev.hadithsearcher';
  static const repository = 'MAymanKH/HadithSearcher';
  static const _platform = MethodChannel('hadithsearcher/updates');

  final UpdateChannel channel;
  final Future<PackageInfo> Function() _packageInfo;
  final Future<http.Response> Function(Uri) _get;
  final Future<int?> Function() _playVersion;
  final DateTime Function() _now;
  final Future<bool> Function(Uri) openUrl;

  bool isChecking = false;
  bool failed = false;
  String? installedVersion;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  UpdateService({
    this.channel = buildUpdateChannel,
    Future<PackageInfo> Function()? packageInfo,
    Future<http.Response> Function(Uri)? get,
    Future<int?> Function()? playVersion,
    DateTime Function()? now,
    Future<bool> Function(Uri)? openUrl,
  }) : _packageInfo = packageInfo ?? PackageInfo.fromPlatform,
       _get = get ?? http.get,
       _playVersion =
           playVersion ??
           (() => _platform.invokeMethod<int>('availableVersionCode')),
       _now = now ?? DateTime.now,
       openUrl =
           openUrl ??
           ((url) => launchUrl(url, mode: LaunchMode.externalApplication));

  Future<AvailableUpdate?> check({bool automatic = false}) async {
    if (isChecking) return null;
    isChecking = true;
    failed = false;
    notifyListeners();
    try {
      final info = await _packageInfo();
      installedVersion = '${info.version}+${info.buildNumber}';
      final installedCode = int.parse(info.buildNumber);
      final preferences = await SharedPreferences.getInstance();
      final key = 'update_check_${channel.name}';
      final last = preferences.getInt(key);
      if (automatic &&
          last != null &&
          _now().difference(DateTime.fromMillisecondsSinceEpoch(last)) <
              const Duration(days: 1)) {
        return null;
      }
      if (automatic) {
        await preferences.setInt(key, _now().millisecondsSinceEpoch);
      }
      switch (channel) {
        case UpdateChannel.play:
          final code = await _playVersion().timeout(
            const Duration(seconds: 10),
          );
          return code != null && code > installedCode
              ? AvailableUpdate(
                  url: Uri.https('play.google.com', '/store/apps/details', {
                    'id': packageName,
                  }),
                )
              : null;
        case UpdateChannel.fdroid:
          final data = await _json(
            Uri.https('f-droid.org', '/api/v1/packages/$packageName'),
          );
          final code = data['suggestedVersionCode'] as int;
          final packages = data['packages'] as List<dynamic>;
          final release = packages.cast<Map<String, dynamic>>().firstWhere(
            (item) => item['versionCode'] == code,
          );
          return code > installedCode
              ? AvailableUpdate(
                  version: release['versionName'] as String,
                  url: Uri.https('f-droid.org', '/packages/$packageName/'),
                )
              : null;
        case UpdateChannel.github:
          final data = await _json(
            Uri.https('api.github.com', '/repos/$repository/releases/latest'),
          );
          if (data['draft'] != false || data['prerelease'] != false) {
            return null;
          }
          final tag = data['tag_name'] as String;
          final assets = data['assets'] as List<dynamic>;
          String? releaseVersion;
          final assetPattern = RegExp(
            r'^HadithSearcher-(\d+\.\d+\.\d+\+\d+)-github\.apk$',
          );
          for (final asset in assets.cast<Map<String, dynamic>>()) {
            if (asset['state'] != 'uploaded') continue;
            final name = asset['name'] as String;
            final match = assetPattern.firstMatch(name);
            if (match != null) {
              releaseVersion = match.group(1);
              break;
            }
            if (name == 'app-release.apk') releaseVersion = tag;
          }
          if (releaseVersion == null ||
              !isNewerRelease(releaseVersion, info.version, installedCode)) {
            return null;
          }
          return AvailableUpdate(
            version: releaseVersion,
            url: Uri.https('github.com', '/$repository/releases/tag/$tag'),
          );
      }
    } catch (error, stack) {
      TelemetryService.report(error, stack, 'updates.${channel.name}.check');
      // Checking for updates must never prevent use of the app while offline.
      failed = true;
      return null;
    } finally {
      isChecking = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _json(Uri url) async {
    final response = await _get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('Update source unavailable');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static bool isNewerRelease(
    String tag,
    String installedVersion,
    int installedCode,
  ) {
    final pattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$');
    final release = pattern.firstMatch(tag);
    final installed = pattern.firstMatch(installedVersion);
    if (release == null || installed == null) return false;
    final code = release.group(4);
    if (code != null) return int.parse(code) > installedCode;
    for (var part = 1; part <= 3; part++) {
      final difference =
          int.parse(release.group(part)!) - int.parse(installed.group(part)!);
      if (difference != 0) return difference > 0;
    }
    return false;
  }
}
