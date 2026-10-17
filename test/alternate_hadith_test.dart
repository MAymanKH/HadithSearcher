import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:hadithsearcher/models/hadith.dart';
import 'package:hadithsearcher/services/api_service.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/widgets/hadith_card.dart';

void main() {
  test(
    'source alternate metadata and endpoint are parsed without inventing a grading',
    () async {
      final source = Hadith.fromJson({
        'hadithId': 'weak',
        'hadith': 'text',
        'hasAlternateHadithSahih': true,
      });
      expect(source.hasAlternateHadithSahih, isTrue);
      final result = await http.runWithClient(
        () => ApiService().getAlternateHadith('weak'),
        () => MockClient((request) async {
          expect(request.url.path, '/v1/site/hadith/alternate/weak');
          return http.Response(
            jsonEncode({
              'data': {
                'hadithId': 'alternate',
                'hadith': 'alternative text',
                'grade': 'source grading',
                'mohdith': 'source scholar',
              },
            }),
            200,
          );
        }),
      );
      expect(result.data!.grade, 'source grading');
      expect(result.data!.mohdith, 'source scholar');
      expect(result.data!.text, 'alternative text');
    },
  );

  testWidgets('alternate action is visible only when supplied by the source', (
    tester,
  ) async {
    for (final available in [false, true]) {
      final hadith = Hadith.fromJson({
        'hadithId': 'test',
        'hadith': 'text',
        'hasAlternateHadithSahih': available,
      });
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsViewModel(),
          child: MaterialApp(
            home: Scaffold(
              body: HadithCard(
                hadith: hadith,
                isFavourite: false,
                onFavouriteToggle: () async {},
              ),
            ),
          ),
        ),
      );
      expect(
        find.byTooltip('البديل الصحيح'),
        available ? findsOneWidget : findsNothing,
      );
    }
    await tester.pumpWidget(const SizedBox());
  });
}
