import 'package:flutter/material.dart';
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
}
