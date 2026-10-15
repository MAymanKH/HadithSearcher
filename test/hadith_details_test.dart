import 'dart:async';
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
import 'package:hadithsearcher/views/hadith_details/hadith_details_view.dart';
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(
    WidgetTester tester,
    Widget home, {
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
          home: home,
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
      final saved = Hadith.fromDatabase(hadith.toDatabase());
      expect(saved.citation.formattedInfo, hadith.citation.formattedInfo);
      expect(HadithOrigins.fromJson({'sources': []}).sources, isEmpty);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'details, citation dialogs, retries, and origins work in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        final paths = <String>[];
        var bookCalls = 0;
        await http.runWithClient(
          () async {
            await mount(
              tester,
              Scaffold(
                body: SingleChildScrollView(
                  child: HadithCard(
                    hadith: Hadith.fromJson(richJson),
                    isFavourite: false,
                    onFavouriteToggle: () async {},
                  ),
                ),
              ),
              dark: dark,
            );
            await tester.tap(find.byTooltip('تفاصيل الحديث'));
            await tester.pumpAndSettle();
            expect(find.byType(HadithDetailsView), findsOneWidget);
            expect(paths, isEmpty);
            expect(
              find.text(richJson['explainGrade']! as String),
              findsOneWidget,
            );
            await tester.ensureVisible(find.text('البخاري'));
            await tester.tap(find.text('البخاري'));
            await tester.pumpAndSettle();
            expect(find.text('ترجمة المحدث'), findsOneWidget);
            await tester.tap(find.text('إغلاق'));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('صحيح البخاري'));
            await tester.tap(find.text('صحيح البخاري'));
            await tester.pumpAndSettle();
            expect(find.text('أعد المحاولة'), findsOneWidget);
            await tester.tap(find.text('أعد المحاولة'));
            await tester.pumpAndSettle();
            expect(
              find.textContaining('المؤلف: الإمام البخاري'),
              findsOneWidget,
            );
            expect(find.textContaining('سنة الطبعة: 1422'), findsOneWidget);
            await tester.tap(find.text('إغلاق'));
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text('رقائق وزهد - النية'),
              250,
              scrollable: find.byType(Scrollable).first,
            );
            expect(find.text(richJson['takhrij']! as String), findsOneWidget);
            await tester.scrollUntilVisible(
              find.text('أصول الحديث وطرق إخراجه'),
              250,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.tap(find.text('أصول الحديث وطرق إخراجه'));
            await tester.pumpAndSettle();
            expect(
              find.textContaining('الإسناد: سلسلة الرواة'),
              findsOneWidget,
            );
            expect(find.textContaining('المتن: نص الرواية'), findsOneWidget);
            expect(paths, [
              '/v1/site/mohdith/256',
              '/v1/site/book/6216',
              '/v1/site/book/6216',
              '/v1/site/hadith/usul/test-hadith',
            ]);
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            paths.add(request.url.path);
            if (request.url.path.contains('/mohdith/')) {
              return response({
                'data': {'name': 'البخاري', 'info': 'ترجمة المحدث'},
              });
            }
            if (request.url.path.contains('/book/')) {
              if (++bookCalls == 1) return response({}, status: 503);
              return response({
                'data': {
                  'name': 'صحيح البخاري',
                  'author': 'الإمام البخاري',
                  'publisher': 'دار النشر',
                  'edition': 'الأولى',
                  'editionYear': 1422,
                },
              });
            }
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
    'saved details keep the offline citation on failure and retry successfully',
    (tester) async {
      final hadith = Hadith.fromJson(richJson);
      var calls = 0;
      await http.runWithClient(
        () async {
          await mount(
            tester,
            HadithDetailsView(
              hadith: Hadith.fromDatabase(hadith.toDatabase()),
              fetchDetails: true,
            ),
          );
          expect(find.text(hadith.text), findsOneWidget);
          expect(find.text('أعد المحاولة'), findsOneWidget);
          await tester.tap(find.text('أعد المحاولة'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('رقائق وزهد - النية'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('رقائق وزهد - النية'), findsOneWidget);
          expect(find.text('أعد المحاولة'), findsNothing);
        },
        () => MockClient(
          (_) async => ++calls == 1
              ? response({}, status: 503)
              : response({'data': richJson}),
        ),
      );
    },
  );

  testWidgets('sparse details hide empty sections and fit large reading text', (
    tester,
  ) async {
    await mount(
      tester,
      HadithDetailsView(
        hadith: Hadith.fromJson({
          'hadithId': 'sparse',
          'hadith': 'حديث طويل للاختبار',
          'grade': 'صحيح',
          'explainGrade': 'صحيح',
          'categories': [
            {
              'id': 'long',
              'name': 'تصنيف موضوعي طويل لاختبار عرض النص على شاشة صغيرة',
            },
          ],
        }),
      ),
      fontSize: 50,
    );
    expect(find.text('التخريج'), findsNothing);
    expect(find.text('المصدر'), findsNothing);
    expect(find.text('المحدث'), findsNothing);
    expect(find.text('أصول الحديث وطرق إخراجه'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving details ignores a late metadata response', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      final settings = SettingsViewModel();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            home: HadithDetailsView(
              hadith: Hadith.fromJson(richJson),
              fetchDetails: true,
            ),
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      pending.complete(response({'data': richJson}));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) => pending.future));
  });

  testWidgets('cards without source IDs load complete details on opening', (
    tester,
  ) async {
    final requests = <String>[];
    await http.runWithClient(
      () async {
        await mount(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: HadithCard(
                hadith: Hadith.fromJson({
                  'hadithId': 'test-hadith',
                  'hadith': 'نص الحديث',
                }),
                isFavourite: false,
                onFavouriteToggle: () async {},
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('تفاصيل الحديث'));
        await tester.pumpAndSettle();
        expect(requests, ['/v1/site/hadith/test-hadith']);
        expect(find.text('البخاري'), findsOneWidget);
        expect(find.text('صحيح البخاري'), findsOneWidget);
      },
      () => MockClient((request) async {
        requests.add(request.url.path);
        return response({'data': richJson});
      }),
    );
  });
}
