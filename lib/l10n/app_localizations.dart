import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Total results for the search mode that produced the displayed results
  ///
  /// In en, this message translates to:
  /// **'Results: {count}'**
  String resultCount(int count);

  /// No description provided for @favourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get favourites;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @readingSettings.
  ///
  /// In en, this message translates to:
  /// **'Hadith and explanation text'**
  String get readingSettings;

  /// No description provided for @privacySettings.
  ///
  /// In en, this message translates to:
  /// **'Privacy and optional analytics'**
  String get privacySettings;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @fontFamily.
  ///
  /// In en, this message translates to:
  /// **'Font family'**
  String get fontFamily;

  /// No description provided for @fontWeight.
  ///
  /// In en, this message translates to:
  /// **'Font weight'**
  String get fontWeight;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @padding.
  ///
  /// In en, this message translates to:
  /// **'Padding'**
  String get padding;

  /// No description provided for @resetSettings.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get resetSettings;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @normalWeight.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normalWeight;

  /// No description provided for @boldWeight.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get boldWeight;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @explanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get explanation;

  /// No description provided for @similar.
  ///
  /// In en, this message translates to:
  /// **'Similar'**
  String get similar;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @alternate.
  ///
  /// In en, this message translates to:
  /// **'Authentic alternative'**
  String get alternate;

  /// No description provided for @similarHadiths.
  ///
  /// In en, this message translates to:
  /// **'Similar hadiths'**
  String get similarHadiths;

  /// No description provided for @noAlternate.
  ///
  /// In en, this message translates to:
  /// **'No authentic alternative available'**
  String get noAlternate;

  /// No description provided for @noSimilar.
  ///
  /// In en, this message translates to:
  /// **'No similar hadiths'**
  String get noSimilar;

  /// No description provided for @noExplanation.
  ///
  /// In en, this message translates to:
  /// **'No explanation available for this hadith'**
  String get noExplanation;

  /// No description provided for @loadingExplanation.
  ///
  /// In en, this message translates to:
  /// **'Finding the explanation...'**
  String get loadingExplanation;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get connectionError;

  /// No description provided for @timeout.
  ///
  /// In en, this message translates to:
  /// **'Request timed out'**
  String get timeout;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error'**
  String get unexpectedError;

  /// No description provided for @connectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again'**
  String get connectionHelp;

  /// No description provided for @timeoutHelp.
  ///
  /// In en, this message translates to:
  /// **'Check that your internet connection is stable and try again'**
  String get timeoutHelp;

  /// No description provided for @explanationTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Check that your internet connection is stable'**
  String get explanationTimeout;

  /// No description provided for @unexpectedHelp.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again'**
  String get unexpectedHelp;

  /// No description provided for @noResultsHelp.
  ///
  /// In en, this message translates to:
  /// **'Try different words or filters'**
  String get noResultsHelp;

  /// No description provided for @searchNoResultsHelp.
  ///
  /// In en, this message translates to:
  /// **'Try different words or filters'**
  String get searchNoResultsHelp;

  /// No description provided for @serverUpdateRequired.
  ///
  /// In en, this message translates to:
  /// **'The search server needs an update to support filter exclusions'**
  String get serverUpdateRequired;

  /// No description provided for @serverUpdateHelp.
  ///
  /// In en, this message translates to:
  /// **'Update the server or select fewer search options'**
  String get serverUpdateHelp;

  /// No description provided for @favouriteAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add the hadith to favourites'**
  String get favouriteAddFailed;

  /// No description provided for @favouriteRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove the hadith from favourites'**
  String get favouriteRemoveFailed;

  /// No description provided for @favouriteAdded.
  ///
  /// In en, this message translates to:
  /// **'Hadith added to favourites'**
  String get favouriteAdded;

  /// No description provided for @favouriteRemoved.
  ///
  /// In en, this message translates to:
  /// **'Hadith removed from favourites'**
  String get favouriteRemoved;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the hadith'**
  String get restoreFailed;

  /// No description provided for @emptyFavourites.
  ///
  /// In en, this message translates to:
  /// **'No hadiths added to favourites'**
  String get emptyFavourites;

  /// No description provided for @additionalInfo.
  ///
  /// In en, this message translates to:
  /// **'Additional information'**
  String get additionalInfo;

  /// No description provided for @hideAdditionalInfo.
  ///
  /// In en, this message translates to:
  /// **'Hide additional information'**
  String get hideAdditionalInfo;

  /// No description provided for @noAdditionalInfo.
  ///
  /// In en, this message translates to:
  /// **'No additional information available from the source'**
  String get noAdditionalInfo;

  /// No description provided for @gradeExplanation.
  ///
  /// In en, this message translates to:
  /// **'Grading explanation'**
  String get gradeExplanation;

  /// No description provided for @takhrij.
  ///
  /// In en, this message translates to:
  /// **'References'**
  String get takhrij;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @hadithSources.
  ///
  /// In en, this message translates to:
  /// **'Hadith sources'**
  String get hadithSources;

  /// No description provided for @hadithChains.
  ///
  /// In en, this message translates to:
  /// **'Sources and chains of transmission'**
  String get hadithChains;

  /// No description provided for @author.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get author;

  /// No description provided for @reviewer.
  ///
  /// In en, this message translates to:
  /// **'Reviewer'**
  String get reviewer;

  /// No description provided for @publisher.
  ///
  /// In en, this message translates to:
  /// **'Publisher'**
  String get publisher;

  /// No description provided for @edition.
  ///
  /// In en, this message translates to:
  /// **'Edition'**
  String get edition;

  /// No description provided for @editionYear.
  ///
  /// In en, this message translates to:
  /// **'Publication year'**
  String get editionYear;

  /// No description provided for @searchByName.
  ///
  /// In en, this message translates to:
  /// **'Search by name...'**
  String get searchByName;

  /// No description provided for @loadingOptions.
  ///
  /// In en, this message translates to:
  /// **'Loading options...'**
  String get loadingOptions;

  /// No description provided for @noMatchingOptions.
  ///
  /// In en, this message translates to:
  /// **'No matching options'**
  String get noMatchingOptions;

  /// No description provided for @emptySearch.
  ///
  /// In en, this message translates to:
  /// **'Enter a search term'**
  String get emptySearch;

  /// No description provided for @hideActiveFilters.
  ///
  /// In en, this message translates to:
  /// **'Hide active filters'**
  String get hideActiveFilters;

  /// No description provided for @showActiveFilters.
  ///
  /// In en, this message translates to:
  /// **'Show active filters'**
  String get showActiveFilters;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Check a hadith...'**
  String get searchHint;

  /// No description provided for @searchAction.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchAction;

  /// No description provided for @advancedSearch.
  ///
  /// In en, this message translates to:
  /// **'Advanced search'**
  String get advancedSearch;

  /// No description provided for @rememberFilters.
  ///
  /// In en, this message translates to:
  /// **'Remember filters'**
  String get rememberFilters;

  /// No description provided for @rememberFiltersHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep filters when you reopen the app'**
  String get rememberFiltersHelp;

  /// No description provided for @specialistSearch.
  ///
  /// In en, this message translates to:
  /// **'Specialist search'**
  String get specialistSearch;

  /// No description provided for @specialistSearchHelp.
  ///
  /// In en, this message translates to:
  /// **'Include differences in scholarly grading and chain details'**
  String get specialistSearchHelp;

  /// No description provided for @searchMethod.
  ///
  /// In en, this message translates to:
  /// **'Search method'**
  String get searchMethod;

  /// No description provided for @searchRange.
  ///
  /// In en, this message translates to:
  /// **'Search scope'**
  String get searchRange;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @excludeWordsHint.
  ///
  /// In en, this message translates to:
  /// **'Words or a phrase to exclude'**
  String get excludeWordsHint;

  /// No description provided for @searchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Search for a hadith'**
  String get searchEmpty;

  /// No description provided for @anyWord.
  ///
  /// In en, this message translates to:
  /// **'Any word'**
  String get anyWord;

  /// No description provided for @allWords.
  ///
  /// In en, this message translates to:
  /// **'All words'**
  String get allWords;

  /// No description provided for @exactMatch.
  ///
  /// In en, this message translates to:
  /// **'Exact match'**
  String get exactMatch;

  /// No description provided for @allHadiths.
  ///
  /// In en, this message translates to:
  /// **'All hadiths'**
  String get allHadiths;

  /// No description provided for @marfoo.
  ///
  /// In en, this message translates to:
  /// **'Prophetic hadiths'**
  String get marfoo;

  /// No description provided for @qudsi.
  ///
  /// In en, this message translates to:
  /// **'Qudsi hadiths'**
  String get qudsi;

  /// No description provided for @athar.
  ///
  /// In en, this message translates to:
  /// **'Companion reports'**
  String get athar;

  /// No description provided for @sharh.
  ///
  /// In en, this message translates to:
  /// **'Hadith explanations'**
  String get sharh;

  /// No description provided for @grade.
  ///
  /// In en, this message translates to:
  /// **'Hadith grade'**
  String get grade;

  /// No description provided for @scholar.
  ///
  /// In en, this message translates to:
  /// **'Scholar'**
  String get scholar;

  /// No description provided for @book.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book;

  /// No description provided for @narrator.
  ///
  /// In en, this message translates to:
  /// **'Narrator'**
  String get narrator;

  /// No description provided for @allGrades.
  ///
  /// In en, this message translates to:
  /// **'All grades'**
  String get allGrades;

  /// No description provided for @sahih.
  ///
  /// In en, this message translates to:
  /// **'Authentic hadiths'**
  String get sahih;

  /// No description provided for @sahihChains.
  ///
  /// In en, this message translates to:
  /// **'Hadiths with authentic chains'**
  String get sahihChains;

  /// No description provided for @weak.
  ///
  /// In en, this message translates to:
  /// **'Weak hadiths'**
  String get weak;

  /// No description provided for @weakChains.
  ///
  /// In en, this message translates to:
  /// **'Hadiths with weak chains'**
  String get weakChains;

  /// No description provided for @allScholars.
  ///
  /// In en, this message translates to:
  /// **'All scholars'**
  String get allScholars;

  /// No description provided for @allBooks.
  ///
  /// In en, this message translates to:
  /// **'All books'**
  String get allBooks;

  /// No description provided for @allNarrators.
  ///
  /// In en, this message translates to:
  /// **'All narrators'**
  String get allNarrators;

  /// No description provided for @specialists.
  ///
  /// In en, this message translates to:
  /// **'Specialists'**
  String get specialists;

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'Data sharing'**
  String get consentTitle;

  /// No description provided for @consentDescription.
  ///
  /// In en, this message translates to:
  /// **'Sharing is optional. You can change your choice later.'**
  String get consentDescription;

  /// No description provided for @analyticsConsent.
  ///
  /// In en, this message translates to:
  /// **'I agree to share usage analytics.'**
  String get analyticsConsent;

  /// No description provided for @diagnosticsConsent.
  ///
  /// In en, this message translates to:
  /// **'I agree to share crash reports.'**
  String get diagnosticsConsent;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @privacyOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the privacy policy.'**
  String get privacyOpenFailed;

  /// No description provided for @consentSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your choice or start the service. Try again.'**
  String get consentSaveFailed;

  /// No description provided for @diagnosticsFailed.
  ///
  /// In en, this message translates to:
  /// **'Crash reporting is currently unavailable.'**
  String get diagnosticsFailed;

  /// No description provided for @analyticsFailed.
  ///
  /// In en, this message translates to:
  /// **'Usage analytics are currently unavailable.'**
  String get analyticsFailed;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates. Try again later.'**
  String get updateCheckFailed;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You are using the latest version.'**
  String get upToDate;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailable;

  /// No description provided for @playUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'An app update is available on Google Play.'**
  String get playUpdateAvailable;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @updateOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the update page. Try again later.'**
  String get updateOpenFailed;

  /// No description provided for @checkingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get checkingUpdates;

  /// No description provided for @checkUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkUpdates;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Hadith Searcher is a free, open source app for searching thousands of prophetic hadiths, with advanced search filters and detailed information about chains of transmission and authenticity.'**
  String get aboutDescription;

  /// No description provided for @sourceCredit.
  ///
  /// In en, this message translates to:
  /// **'All hadiths and information are provided by '**
  String get sourceCredit;

  /// No description provided for @usingApi.
  ///
  /// In en, this message translates to:
  /// **' using '**
  String get usingApi;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @contactDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Contact the developer'**
  String get contactDeveloper;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Library and font licenses'**
  String get licenses;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Hadith Searcher'**
  String get welcomeTitle;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose your app language and theme. You can change them later in settings.'**
  String get welcomeDescription;

  /// No description provided for @apiLanguageNotice.
  ///
  /// In en, this message translates to:
  /// **'Hadiths and source content remain in Arabic.'**
  String get apiLanguageNotice;

  /// No description provided for @preferencesSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your preferences. Try again.'**
  String get preferencesSaveFailed;

  /// No description provided for @backToTop.
  ///
  /// In en, this message translates to:
  /// **'Back to top'**
  String get backToTop;

  /// No description provided for @versionAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available. Update now?'**
  String versionAvailable(String version);

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'Selected: {count}'**
  String selectedCount(int count);

  /// No description provided for @infoAbout.
  ///
  /// In en, this message translates to:
  /// **'Information about {name}'**
  String infoAbout(String name);

  /// No description provided for @optionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load all options. {error}'**
  String optionsLoadFailed(String error);

  /// No description provided for @infoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load information. {error}'**
  String infoLoadFailed(String error);

  /// No description provided for @additionalInfoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load additional information. {error}'**
  String additionalInfoLoadFailed(String error);

  /// No description provided for @allExcept.
  ///
  /// In en, this message translates to:
  /// **'All except {names}'**
  String allExcept(String names);

  /// No description provided for @excludedWords.
  ///
  /// In en, this message translates to:
  /// **'Exclude: {words}'**
  String excludedWords(String words);

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String sourceLabel(String source);

  /// No description provided for @chainLabel.
  ///
  /// In en, this message translates to:
  /// **'Chain: {chain}'**
  String chainLabel(String chain);

  /// No description provided for @textLabel.
  ///
  /// In en, this message translates to:
  /// **'Text: {text}'**
  String textLabel(String text);

  /// No description provided for @narratorLabel.
  ///
  /// In en, this message translates to:
  /// **'Narrator: {name}'**
  String narratorLabel(String name);

  /// No description provided for @pageLabel.
  ///
  /// In en, this message translates to:
  /// **'Page or number: {number}'**
  String pageLabel(String number);

  /// No description provided for @gradeLabel.
  ///
  /// In en, this message translates to:
  /// **'Grading: {grade}'**
  String gradeLabel(String grade);

  /// No description provided for @scholarGradeLabel.
  ///
  /// In en, this message translates to:
  /// **'Grading by {scholar}: {grade}'**
  String scholarGradeLabel(String scholar, String grade);

  /// No description provided for @arabicLanguage.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get arabicLanguage;

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
