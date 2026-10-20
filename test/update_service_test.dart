import 'dart:async';
import 'dart:convert';

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
    version: '3.0.1',
    buildNumber: '202',
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Map<String, dynamic> github({
    int base = 210,
    String version = '3.0.2',
    bool prerelease = false,
    List<String> abis = const ['armeabi-v7a', 'arm64-v8a', 'x86_64'],
  }) => {
    'tag_name': version,
    'draft': false,
    'prerelease': prerelease,
    'assets': [
      for (final abi in abis)
        {
          'state': 'uploaded',
          'name':
              'HadithSearcher-$version+${base + UpdateService.abiCodes[abi]!}-foss-$abi.apk',
        },
    ],
  };

  Map<String, dynamic> fdroid({int base = 210, int? suggested}) => {
    'suggestedVersionCode': suggested ?? base + 3,
    'packages': [
      {'versionCode': 9993, 'versionName': '99.0.0-beta'},
      for (final suffix in [1, 2, 3])
        {'versionCode': base + suffix, 'versionName': '3.0.2'},
    ],
  };

  UpdateService service({
    Object? githubData,
    Object? fdroidData,
    int githubStatus = 200,
    int fdroidStatus = 200,
    List<String> abis = const ['arm64-v8a', 'armeabi-v7a'],
  }) => UpdateService(
    channel: UpdateChannel.foss,
    packageInfo: () async => installed,
    supportedAbis: () async => abis,
    get: (url) async => url.host == 'api.github.com'
        ? http.Response(jsonEncode(githubData ?? github()), githubStatus)
        : http.Response(jsonEncode(fdroidData ?? fdroid()), fdroidStatus),
  );

  test(
    'FOSS offers both sources with independent versions and matching ABI',
    () async {
      final updates = await service(fdroidData: fdroid(base: 220)).check();
      expect(updates.map((item) => item.source), [
        UpdateSource.fdroid,
        UpdateSource.github,
      ]);
      expect(updates.first.versionCode, 221);
      final direct = updates.last;
      expect(direct.versionCode, 211);
      expect(
        direct.url.toString(),
        'https://github.com/MAymanKH/HadithSearcher/releases/download/3.0.2/HadithSearcher-3.0.2+211-foss-arm64-v8a.apk',
      );
    },
  );

  test('same-release ABI suffixes never trigger an update', () async {
    expect(
      await service(
        githubData: github(base: 200),
        fdroidData: fdroid(base: 200),
      ).check(),
      isEmpty,
    );
  });

  test('F-Droid uses its recommended release and a supported ABI', () async {
    final updates = await service(githubData: github(base: 200)).check();
    expect(updates.single.source, UpdateSource.fdroid);
    expect(updates.single.versionCode, 211);
    expect(updates.single.url.host, 'f-droid.org');
    final missingAbi = fdroid();
    (missingAbi['packages'] as List).removeWhere(
      (p) => p['versionCode'] != 213,
    );
    expect(
      await service(
        githubData: github(base: 200),
        fdroidData: missingAbi,
      ).check(),
      isEmpty,
    );
  });

  test(
    'GitHub ignores prereleases, unfinished uploads and incompatible ABIs',
    () async {
      for (final release in [
        github(prerelease: true),
        github(abis: ['x86_64']),
        {
          ...github(),
          'assets': [
            {'state': 'uploaded', 'name': 'app-play.apk'},
          ],
        },
        {
          ...github(),
          'assets': [
            {
              'state': 'new',
              'name': 'HadithSearcher-3.0.2+211-foss-arm64-v8a.apk',
            },
          ],
        },
      ]) {
        expect(
          await service(
            githubData: release,
            fdroidData: fdroid(base: 200),
          ).check(),
          isEmpty,
        );
      }
      final fallback = await service(
        githubData: github(abis: ['armeabi-v7a']),
        fdroidData: fdroid(base: 200),
      ).check();
      expect(fallback.single.versionCode, 212);
    },
  );

  test('one offline source never hides an update from the other', () async {
    for (final failedGithub in [true, false]) {
      final updates = service(
        githubStatus: failedGithub ? 503 : 200,
        fdroidStatus: failedGithub ? 200 : 503,
      );
      final results = await updates.check();
      expect(
        results.single.source,
        failedGithub ? UpdateSource.fdroid : UpdateSource.github,
      );
      expect(updates.failed, isTrue);
    }
  });

  test(
    'F-Droid not listed yet is normal; other failures remain recoverable',
    () async {
      final unlisted = service(fdroidStatus: 404);
      expect((await unlisted.check()).single.source, UpdateSource.github);
      expect(unlisted.failed, isFalse);
      for (final updates in [
        service(githubStatus: 403, fdroidStatus: 503),
        service(githubData: {'assets': []}, fdroidData: {'packages': []}),
      ]) {
        expect(await updates.check(), isEmpty);
        expect(updates.failed, isTrue);
        expect(updates.isChecking, isFalse);
      }
    },
  );

  test('checks both sources concurrently', () async {
    final responses = <String, Completer<http.Response>>{};
    final bothRequested = Completer<void>();
    final updates = UpdateService(
      channel: UpdateChannel.foss,
      packageInfo: () async => installed,
      supportedAbis: () async => ['arm64-v8a'],
      get: (url) {
        final completer = Completer<http.Response>();
        responses[url.host] = completer;
        if (responses.length == 2) bothRequested.complete();
        return completer.future;
      },
    );
    final checking = updates.check();
    await bothRequested.future;
    responses['api.github.com']!.complete(
      http.Response(jsonEncode(github()), 200),
    );
    responses['f-droid.org']!.complete(
      http.Response(jsonEncode(fdroid()), 200),
    );
    expect(await checking, hasLength(2));
  });

  test('Play checks native availability and offers only Play', () async {
    final updates = UpdateService(
      channel: UpdateChannel.play,
      packageInfo: () async => installed,
      playVersion: () async => 210,
      get: (_) => throw StateError('Play must not query FOSS sources'),
    );
    final update = (await updates.check()).single;
    expect(update.source, UpdateSource.play);
    expect(update.url.host, 'play.google.com');
  });

  test(
    'overlapping checks are skipped and disposing during a check is safe',
    () async {
      final result = Completer<int?>();
      final updates = UpdateService(
        channel: UpdateChannel.play,
        packageInfo: () async => installed,
        playVersion: () => result.future,
      );
      final checking = updates.check();
      expect(await updates.check(), isEmpty);
      updates.dispose();
      result.complete(210);
      expect(await checking, hasLength(1));
    },
  );

  test(
    'automatic checks run once daily; manual checks bypass the throttle',
    () async {
      var now = DateTime(2026, 10, 19);
      var calls = 0;
      final updates = UpdateService(
        channel: UpdateChannel.play,
        packageInfo: () async => installed,
        now: () => now,
        playVersion: () async {
          calls++;
          return 210;
        },
      );
      expect(await updates.check(automatic: true), hasLength(1));
      expect(await updates.check(automatic: true), isEmpty);
      expect(calls, 1);
      expect(await updates.check(), hasLength(1));
      now = now.add(const Duration(days: 1));
      expect(await updates.check(automatic: true), hasLength(1));
      expect(calls, 3);
    },
  );
}
