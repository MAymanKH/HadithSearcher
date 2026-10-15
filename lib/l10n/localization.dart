import 'package:flutter/widgets.dart';
import '../models/hadith_citation.dart';
import '../models/search_option.dart';
import '../models/search_params.dart';
import '../models/settings.dart';
import '../services/api_service.dart';
import 'app_localizations.dart';
import 'app_localizations_ar.dart';

export 'app_localizations.dart';

extension LocalizedContext on BuildContext {
  // Standalone widgets can also be embedded outside the app's MaterialApp.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsAr();
}

extension LocalizedTheme on ThemePreference {
  String label(AppLocalizations l) => switch (this) {
    ThemePreference.system => l.systemTheme,
    ThemePreference.light => l.lightTheme,
    ThemePreference.dark => l.darkTheme,
  };
}

extension LocalizedFontWeight on FontWeightPreference {
  String label(AppLocalizations l) => switch (this) {
    FontWeightPreference.normal => l.normalWeight,
    FontWeightPreference.bold => l.boldWeight,
  };
}

extension LocalizedSearchWay on SearchWay {
  String label(AppLocalizations l) => switch (this) {
    SearchWay.anyWord => l.anyWord,
    SearchWay.allWords => l.allWords,
    SearchWay.exactMatch => l.exactMatch,
  };
}

extension LocalizedSearchRange on SearchRange {
  String label(AppLocalizations l) => switch (this) {
    SearchRange.all => l.allHadiths,
    SearchRange.marfoo => l.marfoo,
    SearchRange.qudsi => l.qudsi,
    SearchRange.athar => l.athar,
    SearchRange.sharh => l.sharh,
  };
}

extension LocalizedSearchFilter on SearchFilter {
  String label(AppLocalizations l) => switch (this) {
    SearchFilter.grade => l.grade,
    SearchFilter.scholar => l.scholar,
    SearchFilter.book => l.book,
    SearchFilter.narrator => l.narrator,
  };

  String optionLabel(SearchOption option, AppLocalizations l) {
    if (option.apiCode == '0') {
      return switch (this) {
        SearchFilter.grade => l.allGrades,
        SearchFilter.scholar => l.allScholars,
        SearchFilter.book => l.allBooks,
        SearchFilter.narrator => l.allNarrators,
      };
    }
    if (this == SearchFilter.grade) {
      return switch (option.apiCode) {
        '1' => l.sahih,
        '2' => l.sahihChains,
        '3' => l.weak,
        '4' => l.weakChains,
        _ => option.arabicName,
      };
    }
    return option.arabicName;
  }
}

extension LocalizedApiError on ApiError {
  String title(AppLocalizations l) => switch (this) {
    ApiError.noConnection => l.connectionError,
    ApiError.timeout => l.timeout,
    ApiError.notFound => l.noResults,
    ApiError.unsupportedFilters => l.serverUpdateRequired,
    ApiError.unknown => l.unexpectedError,
  };
}

/// Localizes app-owned error messages from the existing service interfaces.
/// This is deliberately an exact match, never a replacement within API content.
String localizedError(String message, AppLocalizations l) => switch (message) {
  'خطأ بالإتصال بالإنترنت' => l.connectionError,
  'نفذ الوقت' => l.timeout,
  'لا توجد نتائج' => l.noResults,
  'خطأ غير متوقع' => l.unexpectedError,
  'يحتاج خادم البحث إلى تحديث لدعم استبعاد عوامل التصفية' =>
    l.serverUpdateRequired,
  'فشل إزالة الحديث من المفضلة' => l.favouriteRemoveFailed,
  'فشل إضافة الحديث للمفضلة' => l.favouriteAddFailed,
  'تعذر حفظ الاختيار أو تشغيل الخدمة. حاول مرة أخرى.' => l.consentSaveFailed,
  'تعذر تشغيل تقارير الأعطال حالياً.' => l.diagnosticsFailed,
  'تعذر تشغيل إحصاءات الاستخدام حالياً.' => l.analyticsFailed,
  _ => message,
};

extension LocalizedCitation on HadithCitation {
  String localizedGrading(AppLocalizations l) => mohdith.trim().isEmpty
      ? l.gradeLabel(grade)
      : l.scholarGradeLabel(mohdith, grade);

  String localizedAttribution(AppLocalizations l) =>
      '${l.narratorLabel(rawi)}\n${l.sourceLabel(book)}\n${l.pageLabel(numberOrPage)}';

  String localizedInfo(AppLocalizations l) =>
      '${localizedGrading(l)}\n${localizedAttribution(l)}';
}
