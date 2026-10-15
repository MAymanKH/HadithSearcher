import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/services/update_service.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final installed = PackageInfo(
    appName: 'Hadith Searcher',
    packageName: UpdateService.packageName,
    version: '2.1.1',
    buildNumber: '13',
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'overlapping checks are skipped and unmounting during a check is safe',
    () async {
      final result = Completer<int?>();
      final updates = UpdateService(
        channel: UpdateChannel.play,
        packageInfo: () async => installed,
        playVersion: () => result.future,
      );
      final checking = updates.check();
      expect(await updates.check(), isNull);
      updates.dispose();
      result.complete(14);
      expect(await checking, isNotNull);
    },
  );

  UpdateService service(
    UpdateChannel channel, {
    Object? data,
    int status = 200,
    Future<int?> Function()? playVersion,
  }) => UpdateService(
    channel: channel,
    packageInfo: () async => installed,
    get: (_) async => http.Response(jsonEncode(data), status),
    playVersion: playVersion,
  );

  test('Play checks native availability and opens only Play', () async {
    final updates = service(UpdateChannel.play, playVersion: () async => 14);
    final update = await updates.check();
    expect(
      update!.url.toString(),
      'https://play.google.com/store/apps/details?id=${UpdateService.packageName}',
    );
    expect(
      await service(UpdateChannel.play, playVersion: () async => 13).check(),
      isNull,
    );
    expect(
      await service(UpdateChannel.play, playVersion: () async => null).check(),
      isNull,
    );
  });

  test(
    'F-Droid uses suggested version, not a newer unrecommended build',
    () async {
      Map<String, dynamic> catalog(int code) => {
        'suggestedVersionCode': code,
        'packages': [
          {'versionCode': 99, 'versionName': '3.0.0-beta'},
          {'versionCode': 14, 'versionName': '2.1.2'},
          {'versionCode': 13, 'versionName': '2.1.1'},
        ],
      };
      final update = await service(
        UpdateChannel.fdroid,
        data: catalog(14),
      ).check();
      expect(update!.version, '2.1.2');
      expect(update.url.host, 'f-droid.org');
      expect(
        await service(UpdateChannel.fdroid, data: catalog(13)).check(),
        isNull,
      );
    },
  );

  Map<String, dynamic> release({
    String tag = 'v2.1.2',
    bool prerelease = false,
    String asset = 'HadithSearcher-2.1.2+14-github.apk',
  }) => {
    'tag_name': tag,
    'draft': false,
    'prerelease': prerelease,
    'assets': [
      {'state': 'uploaded', 'name': asset},
    ],
  };

  test(
    'GitHub requires a stable release with an installable GitHub APK',
    () async {
      final update = await service(
        UpdateChannel.github,
        data: release(),
      ).check();
      expect(
        update!.url.toString(),
        'https://github.com/MAymanKH/HadithSearcher/releases/tag/v2.1.2',
      );
      for (final data in [
        release(prerelease: true),
        release(asset: 'app-fdroid.apk'),
        release(tag: '2.0.2', asset: 'app-release.apk'),
      ]) {
        expect(await service(UpdateChannel.github, data: data).check(), isNull);
      }
    },
  );

  test(
    'GitHub detects build-only updates from release artifact names',
    () async {
      final update = await service(
        UpdateChannel.github,
        data: release(
          tag: 'v2.1.1',
          asset: 'HadithSearcher-2.1.1+14-github.apk',
        ),
      ).check();
      expect(update!.version, '2.1.1+14');
    },
  );

  test(
    'release comparisons handle numeric versions, build numbers and invalid tags',
    () {
      expect(UpdateService.isNewerRelease('v2.10.0', '2.9.0', 13), isTrue);
      expect(UpdateService.isNewerRelease('2.1.1+14', '2.1.1', 13), isTrue);
      for (final tag in [
        '2.1.1',
        '2.0.9',
        '2.1.1+13',
        '2.1.2+12',
        '2.2.0-beta',
        'latest',
      ]) {
        expect(
          UpdateService.isNewerRelease(tag, '2.1.1', 13),
          isFalse,
          reason: tag,
        );
      }
    },
  );

  test(
    'offline, missing listings, invalid JSON and Play errors are recoverable',
    () async {
      for (final updates in [
        service(UpdateChannel.fdroid, status: 404),
        service(UpdateChannel.github, status: 403),
        service(UpdateChannel.fdroid, data: {'packages': []}),
        service(
          UpdateChannel.play,
          playVersion: () async => throw PlatformException(code: 'unavailable'),
        ),
        UpdateService(
          channel: UpdateChannel.fdroid,
          packageInfo: () async => installed,
          get: (_) async => throw Exception('offline'),
        ),
      ]) {
        expect(await updates.check(), isNull);
        expect(updates.failed, isTrue);
        expect(updates.isChecking, isFalse);
      }
    },
  );

  test(
    'automatic checks run once daily, manual checks bypass the throttle',
    () async {
      var now = DateTime(2026, 10, 15);
      var calls = 0;
      final updates = UpdateService(
        channel: UpdateChannel.play,
        packageInfo: () async => installed,
        now: () => now,
        playVersion: () async {
          calls++;
          return 14;
        },
      );
      expect(await updates.check(automatic: true), isNotNull);
      expect(await updates.check(automatic: true), isNull);
      expect(calls, 1);
      expect(await updates.check(), isNotNull);
      expect(calls, 2);
      now = now.add(const Duration(days: 1));
      expect(await updates.check(automatic: true), isNotNull);
      expect(calls, 3);
    },
  );
}
