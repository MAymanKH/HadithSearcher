import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'telemetry/telemetry_service.dart';

enum UpdateChannel { play, foss }

enum UpdateSource {
  play('Google Play'),
  github('GitHub'),
  fdroid('F-Droid');

  final String label;
  const UpdateSource(this.label);
}

const buildUpdateChannel = appFlavor == 'play'
    ? UpdateChannel.play
    : UpdateChannel.foss;

class AvailableUpdate {
  final UpdateSource source;
  final String? version;
  final int versionCode;
  final Uri url;

  const AvailableUpdate({
    required this.source,
    this.version,
    required this.versionCode,
    required this.url,
  });
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
  final Future<List<String>> Function() _supportedAbis;
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
    Future<List<String>> Function()? supportedAbis,
    Future<bool> Function(Uri)? openUrl,
  }) : _packageInfo = packageInfo ?? PackageInfo.fromPlatform,
       _get = get ?? http.get,
       _playVersion =
           playVersion ??
           (() => _platform.invokeMethod<int>('availableVersionCode')),
       _now = now ?? DateTime.now,
       _supportedAbis =
           supportedAbis ??
           (() async =>
               await _platform.invokeListMethod<String>('supportedAbis') ?? []),
       openUrl =
           openUrl ??
           ((url) => launchUrl(url, mode: LaunchMode.externalApplication));

  Future<List<AvailableUpdate>> check({bool automatic = false}) async {
    if (isChecking) return [];
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
        return [];
      }
      if (automatic) {
        await preferences.setInt(key, _now().millisecondsSinceEpoch);
      }
      if (channel == UpdateChannel.play) {
        final code = await _playVersion().timeout(const Duration(seconds: 10));
        return code != null && code > installedCode
            ? [
                AvailableUpdate(
                  source: UpdateSource.play,
                  versionCode: code,
                  url: Uri.https('play.google.com', '/store/apps/details', {
                    'id': packageName,
                  }),
                ),
              ]
            : [];
      }
      final abis = await _supportedAbis().timeout(const Duration(seconds: 10));
      final results = await Future.wait([
        _checkSource(UpdateSource.github, () => _github(installedCode, abis)),
        _checkSource(UpdateSource.fdroid, () => _fdroid(installedCode, abis)),
      ]);
      return results.whereType<AvailableUpdate>().toList()
        ..sort((a, b) => b.versionCode.compareTo(a.versionCode));
    } catch (error, stack) {
      TelemetryService.report(error, stack, 'updates.${channel.name}.check');
      // Checking for updates must never prevent use of the app while offline.
      failed = true;
      return [];
    } finally {
      isChecking = false;
      if (!_disposed) notifyListeners();
    }
  }

  static const abiCodes = {'arm64-v8a': 1, 'armeabi-v7a': 2, 'x86_64': 3};

  Future<AvailableUpdate?> _checkSource(
    UpdateSource source,
    Future<AvailableUpdate?> Function() check,
  ) async {
    try {
      return await check();
    } catch (error, stack) {
      // The app may not be listed on F-Droid yet.
      if (source == UpdateSource.fdroid && error is _MissingListing) {
        return null;
      }
      failed = true;
      TelemetryService.report(error, stack, 'updates.${source.name}.check');
      return null;
    }
  }

  Future<AvailableUpdate?> _fdroid(int installedCode, List<String> abis) async {
    final data = await _json(
      Uri.https('f-droid.org', '/api/v1/packages/$packageName'),
    );
    final suggested = data['suggestedVersionCode'] as int;
    if (suggested ~/ 10 <= installedCode ~/ 10) return null;
    final packages = (data['packages'] as List).cast<Map<String, dynamic>>();
    for (final abi in abis) {
      final suffix = abiCodes[abi];
      if (suffix == null) continue;
      final code = suggested ~/ 10 * 10 + suffix;
      for (final release in packages) {
        if (release['versionCode'] == code) {
          return AvailableUpdate(
            source: UpdateSource.fdroid,
            version: release['versionName'] as String,
            versionCode: code,
            url: Uri.https('f-droid.org', '/packages/$packageName/'),
          );
        }
      }
    }
    return null;
  }

  Future<AvailableUpdate?> _github(int installedCode, List<String> abis) async {
    final data = await _json(
      Uri.https('api.github.com', '/repos/$repository/releases/latest'),
    );
    if (data['draft'] != false || data['prerelease'] != false) return null;
    final tag = data['tag_name'] as String;
    final pattern = RegExp(
      r'^HadithSearcher-(\d+\.\d+\.\d+)\+(\d+)-foss-(armeabi-v7a|arm64-v8a|x86_64)\.apk$',
    );
    final assets = (data['assets'] as List).cast<Map<String, dynamic>>();
    for (final abi in abis) {
      for (final asset in assets) {
        if (asset['state'] != 'uploaded') continue;
        final name = asset['name'] as String;
        final match = pattern.firstMatch(name);
        if (match == null || match.group(3) != abi) continue;
        final code = int.parse(match.group(2)!);
        if (code % 10 != abiCodes[abi] || code ~/ 10 <= installedCode ~/ 10) {
          continue;
        }
        if (tag.replaceFirst(RegExp(r'^v'), '') != match.group(1)) continue;
        return AvailableUpdate(
          source: UpdateSource.github,
          version: match.group(1),
          versionCode: code,
          url: Uri.https(
            'github.com',
            '/$repository/releases/download/$tag/$name',
          ),
        );
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _json(Uri url) async {
    final response = await _get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode == 404) throw const _MissingListing();
    if (response.statusCode != 200) {
      throw StateError('Update source unavailable');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

class _MissingListing implements Exception {
  const _MissingListing();
}
