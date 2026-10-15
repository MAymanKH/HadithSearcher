import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/services/shared_text_service.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'telemetry/fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a warm share arriving during initialization takes precedence',
    () async {
      final initial = Completer<String?>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SharedTextService.channel,
        (_) => initial.future,
      );
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(SharedTextService.channel, null),
      );
      final initialization = SharedTextService.instance.initialize();
      final delivered = Completer<void>();
      TestWidgetsFlutterBinding.instance.channelBuffers.push(
        SharedTextService.channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('sharedText', 'newer share'),
        ),
        (_) => delivered.complete(),
      );
      await delivered.future;
      initial.complete('older initial share');
      await initialization;
      expect(SharedTextService.instance.takePendingText(), 'newer share');
    },
  );

  testWidgets(
    'cold shares wait for welcome and consent; warm shares open editable search once',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SharedTextService.channel,
        (call) async =>
            call.method == 'consumeSharedText' ? ' initial shared text ' : null,
      );
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(SharedTextService.channel, null),
      );
      await SharedTextService.instance.initialize();
      final telemetry = TelemetryService(
        preferences: await SharedPreferences.getInstance(),
        backend: FakeBackend(),
      );
      addTearDown(telemetry.dispose);
      await tester.pumpWidget(
        HadithSearcherApp(
          initialThemeMode: ThemeMode.light,
          telemetry: telemetry,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byKey(const Key('complete-welcome')), findsOneWidget);
      expect(find.text('initial shared text'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('complete-welcome')));
      await tester.tap(find.byKey(const Key('complete-welcome')));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byKey(const Key('analytics-consent')), findsOneWidget);
      await telemetry.save(diagnostics: false, analytics: false);
      await tester.pumpAndSettle();
      expect(find.text('initial shared text'), findsOneWidget);
      await tester.tap(find.text('الإعدادات').last);
      await tester.pumpAndSettle();
      final accepted = Completer<void>();
      tester.binding.channelBuffers.push(
        SharedTextService.channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('sharedText', 'second shared text'),
        ),
        (_) => accepted.complete(),
      );
      await accepted.future;
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(find.text('second shared text'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'edited phrase');
      await tester.tap(find.text('الإعدادات').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('البحث').last);
      await tester.pumpAndSettle();
      expect(find.text('edited phrase'), findsOneWidget);
      expect(SharedTextService.instance.takePendingText(), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
