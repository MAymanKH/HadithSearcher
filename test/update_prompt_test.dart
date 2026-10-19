import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/services/update_service.dart';
import 'package:hadithsearcher/widgets/update_prompt.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> showApp(WidgetTester tester, UpdateService updates) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: updates,
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const UpdatePrompt(child: Scaffold(body: UpdateCheckButton())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  UpdateService service({
    Future<int?> Function()? check,
    Future<bool> Function(Uri)? open,
  }) => UpdateService(
    channel: UpdateChannel.play,
    packageInfo: () async => PackageInfo(
      appName: 'test',
      packageName: UpdateService.packageName,
      version: '2.1.1',
      buildNumber: '13',
    ),
    playVersion: check ?? () async => 14,
    openUrl: open,
  );

  testWidgets(
    'prompts automatically, Later dismisses, manual check opens the store',
    (tester) async {
      Uri? opened;
      await showApp(
        tester,
        service(
          open: (url) async {
            opened = url;
            return true;
          },
        ),
      );
      expect(find.text('تحديث جديد متاح'), findsOneWidget);
      await tester.tap(find.text('لاحقاً'));
      await tester.pumpAndSettle();
      expect(opened, isNull);
      await tester.tap(find.text('التحقق من التحديثات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تحديث الآن'));
      await tester.pumpAndSettle();
      expect(opened!.host, 'play.google.com');
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'automatic failures are silent and manual failures are explained',
    (tester) async {
      await showApp(
        tester,
        service(check: () async => throw Exception('offline')),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.text('التحقق من التحديثات'));
      await tester.pumpAndSettle();
      expect(
        find.text('تعذر التحقق من التحديثات. حاول مرة أخرى لاحقاً.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('current version reports no update on manual check', (
    tester,
  ) async {
    await showApp(tester, service(check: () async => null));
    await tester.tap(find.text('التحقق من التحديثات'));
    await tester.pumpAndSettle();
    expect(find.text('أنت تستخدم أحدث إصدار متاح.'), findsOneWidget);
  });

  testWidgets('cannot open update page reports a recoverable error', (
    tester,
  ) async {
    await showApp(tester, service(open: (_) async => false));
    await tester.tap(find.text('تحديث الآن'));
    await tester.pumpAndSettle();
    expect(
      find.text('تعذر فتح صفحة التحديث. حاول مرة أخرى لاحقاً.'),
      findsOneWidget,
    );
  });
  for (final source in [UpdateSource.github, UpdateSource.fdroid]) {
    testWidgets('FOSS popup lets the user choose ${source.label}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      Uri? opened;
      await showApp(
        tester,
        UpdateService(
          channel: UpdateChannel.foss,
          packageInfo: () async => PackageInfo(
            appName: 'test',
            packageName: UpdateService.packageName,
            version: '3.0.1',
            buildNumber: '202',
          ),
          supportedAbis: () async => ['arm64-v8a'],
          get: (url) async => http.Response(
            jsonEncode(
              url.host == 'api.github.com'
                  ? {
                      'tag_name': '3.0.2',
                      'draft': false,
                      'prerelease': false,
                      'assets': [
                        {
                          'state': 'uploaded',
                          'name': 'HadithSearcher-3.0.2+212-foss-arm64-v8a.apk',
                        },
                      ],
                    }
                  : {
                      'suggestedVersionCode': 223,
                      'packages': [
                        {'versionCode': 222, 'versionName': '3.0.3'},
                      ],
                    },
            ),
            200,
          ),
          openUrl: (url) async {
            opened = url;
            return true;
          },
        ),
      );
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('F-Droid'), findsOneWidget);
      expect(find.textContaining('3.0.2'), findsOneWidget);
      expect(find.textContaining('3.0.3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(source.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(source.label));
      await tester.pumpAndSettle();
      expect(
        opened!.host,
        source == UpdateSource.github ? 'github.com' : 'f-droid.org',
      );
      expect(find.byType(AlertDialog), findsNothing);
    });
  }
}
