import 'dart:async';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hadithsearcher/services/database_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/models/hadith.dart';
import 'package:hadithsearcher/models/hadith_details.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/widgets/hadith_additional_info.dart';
import 'package:hadithsearcher/widgets/hadith_card_layout.dart';
import 'package:hadithsearcher/widgets/hadith_card.dart';

const richJson = <String, Object>{
  'hadithId': 'test-hadith',
  'hadith': 'إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى.',
  'rawi': 'عمر بن الخطاب',
  'mohdith': 'البخاري',
  'mohdithId': '256',
  'book': 'صحيح البخاري',
  'bookId': 6216,
  'numberOrPage': '1',
  'grade': 'صحيح',
  'explainGrade': 'توضيح حكم المحدث كما ورد في المصدر',
  'takhrij': 'أخرجه البخاري (1)، ومسلم (1907).',
  'categories': [
    {'id': 'intention', 'name': 'رقائق وزهد - النية'},
  ],
  'hasUsulHadith': true,
};

http.Response response(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    final directory = await Directory.systemTemp.createTemp('hadith-details-');
    await databaseFactory.setDatabasesPath(directory.path);
    final db = await DatabaseService().database;
    addTearDown(() async {
      await db.close();
      await directory.delete(recursive: true);
    });
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(
    WidgetTester tester,
    Hadith hadith, {
    bool dark = false,
    int fontSize = 20,
  }) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = SettingsViewModel();
    addTearDown(settings.dispose);
    await settings.setFontSize(fontSize);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          builder: (_, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: Scaffold(
            body: SingleChildScrollView(
              child: HadithCard(
                hadith: hadith,
                isFavourite: false,
                onFavouriteToggle: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test(
    'optional fields and stored citations parse without losing their values',
    () {
      final hadith = Hadith.fromJson(richJson);
      expect(hadith.bookId, '6216');
      expect(hadith.mohdithId, '256');
      expect(hadith.categories.single.name, 'رقائق وزهد - النية');
      expect(hadith.hasUsulHadith, isTrue);
      expect(
        Hadith.fromJson({'hadith': 'text', 'categories': null}).categories,
        isEmpty,
      );
      expect(
        Hadith.fromDatabase(hadith.toDatabase()).formattedInfo,
        hadith.formattedInfo,
      );
      expect(HadithOrigins.fromJson({'sources': []}).sources, isEmpty);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'extra information slides inside the existing card in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        final hadith = Hadith.fromJson(richJson);
        await http.runWithClient(
          () async {
            await mount(tester, hadith, dark: dark);
            expect(find.byTooltip('تفاصيل الحديث'), findsNothing);
            expect(
              find.text('توضيح الحكم: ${hadith.explainGrade}'),
              findsNothing,
            );
            final collapsed = tester
                .getSize(find.byType(HadithCardLayout))
                .height;
            await tester.ensureVisible(find.text('معلومات إضافية'));
            await tester.tap(find.text('معلومات إضافية'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            final during = tester.getSize(find.byType(HadithCardLayout)).height;
            await tester.pumpAndSettle();
            final expanded = tester
                .getSize(find.byType(HadithCardLayout))
                .height;
            expect(during, inExclusiveRange(collapsed, expanded));
            expect(find.byType(Scaffold), findsOneWidget);
            expect(find.text(hadith.text), findsOneWidget);
            expect(find.text(hadith.citation.grading), findsOneWidget);
            expect(find.text(hadith.citation.attribution), findsOneWidget);
            expect(
              find.text('توضيح الحكم: ${hadith.explainGrade}'),
              findsOneWidget,
            );
            expect(find.text('التخريج: ${hadith.takhrij}'), findsOneWidget);
            expect(
              find.text('التصنيف الموضوعي: رقائق وزهد - النية'),
              findsOneWidget,
            );
            expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
            await tester.ensureVisible(find.text('أصول الحديث وطرق إخراجه'));
            await tester.runAsync(() async {
              await tester.tap(find.text('أصول الحديث وطرق إخراجه'));
              await Future<void>.delayed(const Duration(milliseconds: 50));
            });
            await tester.pumpAndSettle();
            expect(
              find.textContaining('الإسناد: سلسلة الرواة'),
              findsOneWidget,
            );
            expect(find.textContaining('المتن: نص الرواية'), findsOneWidget);
            await tester.tap(find.text('إغلاق'));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('إخفاء المعلومات الإضافية'));
            await tester.tap(find.text('إخفاء المعلومات الإضافية'));
            await tester.pumpAndSettle();
            expect(
              find.text('توضيح الحكم: ${hadith.explainGrade}'),
              findsNothing,
            );
            expect(
              find.text('التصنيف الموضوعي: رقائق وزهد - النية'),
              findsNothing,
            );
            expect(
              tester.getSize(find.byType(HadithCardLayout)).height,
              collapsed,
            );
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            expect(request.url.path, '/v1/site/hadith/usul/test-hadith');
            return response({
              'data': {
                'usulHadith': {
                  'sources': [
                    {
                      'source': 'صحيح البخاري (1)',
                      'chain': 'سلسلة الرواة',
                      'hadithText': 'نص الرواية',
                    },
                  ],
                },
              },
            });
          }),
        );
      },
    );
  }

  testWidgets(
    'saved information loads only on expansion and retries without replacing the citation',
    (tester) async {
      final hadith = Hadith.fromJson(richJson);
      final saved = Hadith.fromDatabase(hadith.toDatabase());
      var calls = 0;
      await http.runWithClient(
        () async {
          await mount(tester, saved);
          expect(calls, 0);
          await tester.ensureVisible(find.text('معلومات إضافية'));
          await tester.runAsync(() async {
            await tester.tap(find.text('معلومات إضافية'));
            await Future<void>.delayed(const Duration(milliseconds: 50));
          });
          await tester.pumpAndSettle();
          expect(find.text(saved.citation.attribution), findsOneWidget);
          expect(find.text('أعد المحاولة'), findsOneWidget);
          await tester.ensureVisible(find.text('أعد المحاولة'));
          await tester.runAsync(() async {
            await tester.tap(find.text('أعد المحاولة'));
            await Future<void>.delayed(const Duration(milliseconds: 50));
          });
          await tester.pumpAndSettle();
          expect(
            find.text('التصنيف الموضوعي: رقائق وزهد - النية'),
            findsOneWidget,
          );
          expect(find.text('أعد المحاولة'), findsNothing);
          await tester.ensureVisible(find.text('إخفاء المعلومات الإضافية'));
          await tester.tap(find.text('إخفاء المعلومات الإضافية'));
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            await tester.tap(find.text('معلومات إضافية'));
            await Future<void>.delayed(const Duration(milliseconds: 50));
          });
          await tester.pumpAndSettle();
          expect(calls, 2);
        },
        () => MockClient(
          (_) async => ++calls == 1
              ? response({}, status: 503)
              : response({'data': richJson}),
        ),
      );
    },
  );

  testWidgets('additional labels and toggle follow the basic reading style', (
    tester,
  ) async {
    final hadith = Hadith.fromJson(richJson);
    await mount(tester, hadith, fontSize: 40);
    final basicStyle = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .firstWhere((text) => text.data == hadith.text)
        .style!;
    final toggle = find.text('معلومات إضافية');
    final toggleStyle = tester.widget<Text>(toggle).style!;
    expect(toggleStyle.fontSize, basicStyle.fontSize);
    expect(toggleStyle.fontFamily, basicStyle.fontFamily);
    expect(toggleStyle.fontWeight, basicStyle.fontWeight);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    for (final line in [
      'توضيح الحكم: ${hadith.explainGrade}',
      'التخريج: ${hadith.takhrij}',
      'التصنيف الموضوعي: رقائق وزهد - النية',
    ]) {
      final text = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .firstWhere((text) => text.data == line);
      expect(text.style!.fontSize, basicStyle.fontSize);
      expect(text.style!.fontFamily, basicStyle.fontFamily);
      expect(text.style!.fontWeight, basicStyle.fontWeight);
    }
    expect(find.byType(Chip), findsNothing);
    expect(find.text('التخريج'), findsNothing);
    expect(find.text('التصنيف الموضوعي'), findsNothing);
    final expandedStyle = tester
        .widget<Text>(find.text('إخفاء المعلومات الإضافية'))
        .style!;
    expect(expandedStyle.fontSize, basicStyle.fontSize);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'identical grading is not repeated and long tags fit large reading text',
    (tester) async {
      final json = {
        ...richJson,
        'explainGrade': richJson['grade'],
        'categories': [
          {
            'id': 'long',
            'name': 'تصنيف موضوعي طويل لاختبار عرض النص على شاشة صغيرة',
          },
        ],
      };
      await mount(tester, Hadith.fromJson(json), fontSize: 50);
      await tester.ensureVisible(find.text('معلومات إضافية'));
      await tester.tap(find.text('معلومات إضافية'));
      await tester.pumpAndSettle();
      expect(find.textContaining('توضيح الحكم:'), findsNothing);
      expect(find.text('المحدث'), findsNothing);
      expect(find.text('المصدر'), findsNothing);
      await tester.ensureVisible(find.text('أصول الحديث وطرق إخراجه'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('collapsing or removing a card during loading is safe', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    await http.runWithClient(
      () async {
        await mount(
          tester,
          Hadith.fromDatabase(Hadith.fromJson(richJson).toDatabase()),
        );
        await tester.ensureVisible(find.text('معلومات إضافية'));
        await tester.tap(find.text('معلومات إضافية'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        await tester.tap(find.text('إخفاء المعلومات الإضافية'));
        await tester.pumpAndSettle();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(calls, 1);
        await tester.pumpWidget(const SizedBox());
        pending.complete(response({'data': richJson}));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      () => MockClient((_) {
        calls++;
        return pending.future;
      }),
    );
  });

  testWidgets(
    'cards with no additional information do not show an empty expansion',
    (tester) async {
      await mount(
        tester,
        Hadith.fromJson({
          'hadithId': 'plain',
          'hadith': 'حديث',
          'grade': 'صحيح',
          'explainGrade': 'صحيح',
          'bookId': '6216',
          'mohdithId': '256',
        }),
      );
      expect(find.byType(HadithAdditionalInfo), findsOneWidget);
      expect(find.text('معلومات إضافية'), findsNothing);
    },
  );
}
