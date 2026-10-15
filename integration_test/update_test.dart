import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/services/update_service.dart';
import 'package:hadithsearcher/widgets/update_prompt.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('each channel prompts using the installed Android build number', (
    tester,
  ) async {
    final info = await PackageInfo.fromPlatform();
    final nextCode = int.parse(info.buildNumber) + 1;
    for (final channel in UpdateChannel.values) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('update_check_${channel.name}');
      Uri? opened;
      final updates = UpdateService(
        channel: channel,
        playVersion: () async => nextCode,
        get: (url) async => http.Response(
          jsonEncode(
            channel == UpdateChannel.fdroid
                ? {
                    'suggestedVersionCode': nextCode,
                    'packages': [
                      {'versionName': '99.0.0', 'versionCode': nextCode},
                    ],
                  }
                : {
                    'tag_name': 'v99.0.0',
                    'draft': false,
                    'prerelease': false,
                    'assets': [
                      {
                        'state': 'uploaded',
                        'name': 'HadithSearcher-99.0.0+$nextCode-github.apk',
                      },
                    ],
                  },
          ),
          200,
        ),
        openUrl: (url) async {
          opened = url;
          return true;
        },
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: updates,
          child: MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const UpdatePrompt(
              child: Scaffold(body: UpdateCheckButton()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Package info and preferences use real Android platform channels.
      for (
        var attempt = 0;
        attempt < 50 && find.byType(AlertDialog).evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.text('تحديث جديد متاح'),
        findsOneWidget,
        reason: channel.name,
      );
      await tester.tap(find.text('تحديث الآن'));
      await tester.pumpAndSettle();
      expect(opened!.host, switch (channel) {
        UpdateChannel.play => 'play.google.com',
        UpdateChannel.fdroid => 'f-droid.org',
        UpdateChannel.github => 'github.com',
      });
      await tester.pumpWidget(const SizedBox());
      updates.dispose();
    }
  });

  testWidgets(
    'native update bridge is registered only with Play support in Play',
    (tester) async {
      const platform = MethodChannel('hadithsearcher/updates');
      if (appFlavor == 'play') {
        try {
          final code = await platform
              .invokeMethod<int>('availableVersionCode')
              .timeout(const Duration(seconds: 15));
          expect(code, anyOf(isNull, isA<int>()));
        } on PlatformException catch (error) {
          // Sideloaded emulator builds are not owned by Google Play.
          expect(error.code, 'play_update');
        }
      } else {
        await expectLater(
          platform.invokeMethod<int>('availableVersionCode'),
          throwsA(isA<MissingPluginException>()),
        );
      }
      expect(
        buildUpdateChannel,
        appFlavor == 'play'
            ? UpdateChannel.play
            : const String.fromEnvironment('UPDATE_CHANNEL') == 'github'
            ? UpdateChannel.github
            : UpdateChannel.fdroid,
      );
    },
  );
}
