// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get search => 'Search';

  @override
  String resultCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Results: $countString';
  }

  @override
  String get favourites => 'Favourites';

  @override
  String get settings => 'Settings';

  @override
  String get about => 'About';

  @override
  String get readingSettings => 'Hadith and explanation text';

  @override
  String get privacySettings => 'Privacy and optional analytics';

  @override
  String get theme => 'Theme';

  @override
  String get fontFamily => 'Font family';

  @override
  String get fontWeight => 'Font weight';

  @override
  String get fontSize => 'Font size';

  @override
  String get padding => 'Padding';

  @override
  String get resetSettings => 'Reset to defaults';

  @override
  String get systemTheme => 'System default';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get normalWeight => 'Normal';

  @override
  String get boldWeight => 'Bold';

  @override
  String get close => 'Close';

  @override
  String get copy => 'Copy';

  @override
  String get retry => 'Try again';

  @override
  String get tryAgain => 'Try again';

  @override
  String get explanation => 'Explanation';

  @override
  String get similar => 'Similar';

  @override
  String get share => 'Share';

  @override
  String get alternate => 'Authentic alternative';

  @override
  String get similarHadiths => 'Similar hadiths';

  @override
  String get noAlternate => 'No authentic alternative available';

  @override
  String get noSimilar => 'No similar hadiths';

  @override
  String get noSimilarForHadith =>
      'No similar hadiths available for this hadith';

  @override
  String get noExplanation => 'No explanation available for this hadith';

  @override
  String get loadingExplanation => 'Finding the explanation...';

  @override
  String get connectionError => 'Connection error';

  @override
  String get timeout => 'Request timed out';

  @override
  String get noResults => 'No results';

  @override
  String get unexpectedError => 'Unexpected error';

  @override
  String get connectionHelp => 'Check your internet connection and try again';

  @override
  String get timeoutHelp =>
      'Check that your internet connection is stable and try again';

  @override
  String get explanationTimeout =>
      'Request timed out. Check that your internet connection is stable';

  @override
  String get unexpectedHelp => 'Something went wrong. Try again';

  @override
  String get noResultsHelp => 'Try different words or filters';

  @override
  String get searchNoResultsHelp => 'Try different words or filters';

  @override
  String get serverUpdateRequired =>
      'The search server needs an update to support filter exclusions';

  @override
  String get serverUpdateHelp =>
      'Update the server or select fewer search options';

  @override
  String get favouriteAddFailed => 'Could not add the hadith to favourites';

  @override
  String get favouriteRemoveFailed =>
      'Could not remove the hadith from favourites';

  @override
  String get favouriteAdded => 'Hadith added to favourites';

  @override
  String get favouriteRemoved => 'Hadith removed from favourites';

  @override
  String get undo => 'Undo';

  @override
  String get restoreFailed => 'Could not restore the hadith';

  @override
  String get emptyFavourites => 'No hadiths added to favourites';

  @override
  String get additionalInfo => 'Additional information';

  @override
  String get hideAdditionalInfo => 'Hide additional information';

  @override
  String get noAdditionalInfo =>
      'No additional information available from the source';

  @override
  String get gradeExplanation => 'Grading explanation';

  @override
  String get takhrij => 'References';

  @override
  String get categories => 'Categories';

  @override
  String get hadithSources => 'Hadith sources';

  @override
  String get hadithChains => 'Sources and chains of transmission';

  @override
  String get author => 'Author';

  @override
  String get reviewer => 'Reviewer';

  @override
  String get publisher => 'Publisher';

  @override
  String get edition => 'Edition';

  @override
  String get editionYear => 'Publication year';

  @override
  String get searchByName => 'Search by name...';

  @override
  String get loadingOptions => 'Loading options...';

  @override
  String get noMatchingOptions => 'No matching options';

  @override
  String get emptySearch => 'Enter a search term';

  @override
  String get hideActiveFilters => 'Hide active filters';

  @override
  String get showActiveFilters => 'Show active filters';

  @override
  String get filters => 'Filters';

  @override
  String get searchHint => 'Check a hadith...';

  @override
  String get searchAction => 'Search';

  @override
  String get advancedSearch => 'Advanced search';

  @override
  String get rememberFilters => 'Remember filters';

  @override
  String get rememberFiltersHelp => 'Keep filters when you reopen the app';

  @override
  String get specialistSearch => 'Specialist search';

  @override
  String get specialistSearchHelp =>
      'Include differences in scholarly grading and chain details';

  @override
  String get searchMethod => 'Search method';

  @override
  String get searchRange => 'Search scope';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get excludeWordsHint => 'Words or a phrase to exclude';

  @override
  String get searchEmpty => 'Search for a hadith';

  @override
  String get anyWord => 'Any word';

  @override
  String get allWords => 'All words';

  @override
  String get exactMatch => 'Exact match';

  @override
  String get allHadiths => 'All hadiths';

  @override
  String get marfoo => 'Prophetic hadiths';

  @override
  String get qudsi => 'Qudsi hadiths';

  @override
  String get athar => 'Companion reports';

  @override
  String get sharh => 'Hadith explanations';

  @override
  String get grade => 'Hadith grade';

  @override
  String get scholar => 'Scholar';

  @override
  String get book => 'Book';

  @override
  String get narrator => 'Narrator';

  @override
  String get allGrades => 'All grades';

  @override
  String get sahih => 'Authentic hadiths';

  @override
  String get sahihChains => 'Hadiths with authentic chains';

  @override
  String get weak => 'Weak hadiths';

  @override
  String get weakChains => 'Hadiths with weak chains';

  @override
  String get allScholars => 'All scholars';

  @override
  String get allBooks => 'All books';

  @override
  String get allNarrators => 'All narrators';

  @override
  String get specialists => 'Specialists';

  @override
  String get consentTitle => 'Data sharing';

  @override
  String get consentDescription =>
      'Sharing is optional. You can change your choice later.';

  @override
  String get analyticsConsent => 'I agree to share usage analytics.';

  @override
  String get diagnosticsConsent => 'I agree to share crash reports.';

  @override
  String get continueAction => 'Continue';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get privacyOpenFailed => 'Could not open the privacy policy.';

  @override
  String get consentSaveFailed =>
      'Could not save your choice or start the service. Try again.';

  @override
  String get diagnosticsFailed => 'Crash reporting is currently unavailable.';

  @override
  String get analyticsFailed => 'Usage analytics are currently unavailable.';

  @override
  String get updateCheckFailed =>
      'Could not check for updates. Try again later.';

  @override
  String get upToDate => 'You are using the latest version.';

  @override
  String get updateAvailable => 'Update available';

  @override
  String get playUpdateAvailable =>
      'An app update is available on Google Play.';

  @override
  String get later => 'Later';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateOpenFailed =>
      'Could not open the update page. Try again later.';

  @override
  String get checkingUpdates => 'Checking...';

  @override
  String get checkUpdates => 'Check for updates';

  @override
  String get aboutDescription =>
      'Hadith Searcher is a free, open source app for searching thousands of prophetic hadiths, with advanced search filters and detailed information about chains of transmission and authenticity.';

  @override
  String get sourceCredit => 'All hadiths and information are provided by ';

  @override
  String get usingApi => ' using ';

  @override
  String get code => 'Code';

  @override
  String get support => 'Support';

  @override
  String get update => 'Update';

  @override
  String get contactDeveloper => 'Contact the developer';

  @override
  String get website => 'Website';

  @override
  String get email => 'Email';

  @override
  String get licenses => 'Library and font licenses';

  @override
  String get language => 'Language';

  @override
  String get welcomeTitle => 'Welcome to Hadith Searcher';

  @override
  String get welcomeDescription =>
      'Choose your app language and theme. You can change them later in settings.';

  @override
  String get apiLanguageNotice =>
      'Hadiths and source content remain in Arabic.';

  @override
  String get preferencesSaveFailed =>
      'Could not save your preferences. Try again.';

  @override
  String get backToTop => 'Back to top';

  @override
  String versionAvailable(String version) {
    return 'Version $version is available. Update now?';
  }

  @override
  String selectedCount(int count) {
    return 'Selected: $count';
  }

  @override
  String infoAbout(String name) {
    return 'Information about $name';
  }

  @override
  String optionsLoadFailed(String error) {
    return 'Could not load all options. $error';
  }

  @override
  String infoLoadFailed(String error) {
    return 'Could not load information. $error';
  }

  @override
  String additionalInfoLoadFailed(String error) {
    return 'Could not load additional information. $error';
  }

  @override
  String allExcept(String names) {
    return 'All except $names';
  }

  @override
  String excludedWords(String words) {
    return 'Exclude: $words';
  }

  @override
  String sourceLabel(String source) {
    return 'Source: $source';
  }

  @override
  String chainLabel(String chain) {
    return 'Chain: $chain';
  }

  @override
  String textLabel(String text) {
    return 'Text: $text';
  }

  @override
  String narratorLabel(String name) {
    return 'Narrator: $name';
  }

  @override
  String pageLabel(String number) {
    return 'Page or number: $number';
  }

  @override
  String gradeLabel(String grade) {
    return 'Grading: $grade';
  }

  @override
  String scholarGradeLabel(String scholar, String grade) {
    return 'Grading by $scholar: $grade';
  }

  @override
  String get arabicLanguage => 'العربية';

  @override
  String get englishLanguage => 'English';
}
