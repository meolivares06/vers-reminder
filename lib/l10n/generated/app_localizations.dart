import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en'),
    Locale('es'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Vers Reminder'**
  String get appTitle;

  /// No description provided for @verseListTitle.
  ///
  /// In en, this message translates to:
  /// **'Verses'**
  String get verseListTitle;

  /// No description provided for @addVerse.
  ///
  /// In en, this message translates to:
  /// **'Add verse'**
  String get addVerse;

  /// No description provided for @editVerse.
  ///
  /// In en, this message translates to:
  /// **'Edit verse'**
  String get editVerse;

  /// No description provided for @newVerse.
  ///
  /// In en, this message translates to:
  /// **'New verse'**
  String get newVerse;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete verse?'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this verse?'**
  String get confirmDeleteBody;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Yes, delete'**
  String get confirm;

  /// Delete confirmation with citation name
  ///
  /// In en, this message translates to:
  /// **'Delete \"{citation}\"?'**
  String confirmDeleteCitation(String citation);

  /// No description provided for @citation.
  ///
  /// In en, this message translates to:
  /// **'Citation'**
  String get citation;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// No description provided for @textEs.
  ///
  /// In en, this message translates to:
  /// **'Text (Spanish)'**
  String get textEs;

  /// No description provided for @textPt.
  ///
  /// In en, this message translates to:
  /// **'Text (Portuguese)'**
  String get textPt;

  /// No description provided for @categoriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesLabel;

  /// No description provided for @categoryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryNameLabel;

  /// Placeholder hint for citation input
  ///
  /// In en, this message translates to:
  /// **'e.g. John 3:16'**
  String get citationHint;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get selectCategory;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @newCategoryName.
  ///
  /// In en, this message translates to:
  /// **'New category name'**
  String get newCategoryName;

  /// No description provided for @selectAtLeastOneCategory.
  ///
  /// In en, this message translates to:
  /// **'Select at least one category'**
  String get selectAtLeastOneCategory;

  /// No description provided for @noVerses.
  ///
  /// In en, this message translates to:
  /// **'No verses yet'**
  String get noVerses;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// No description provided for @portuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get portuguese;

  /// No description provided for @autoChange.
  ///
  /// In en, this message translates to:
  /// **'Auto change wallpaper'**
  String get autoChange;

  /// No description provided for @freq15min.
  ///
  /// In en, this message translates to:
  /// **'15 min'**
  String get freq15min;

  /// No description provided for @freq30min.
  ///
  /// In en, this message translates to:
  /// **'30 min'**
  String get freq30min;

  /// No description provided for @freq1h.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get freq1h;

  /// No description provided for @freq3h.
  ///
  /// In en, this message translates to:
  /// **'3 hours'**
  String get freq3h;

  /// No description provided for @freq6h.
  ///
  /// In en, this message translates to:
  /// **'6 hours'**
  String get freq6h;

  /// No description provided for @freq12h.
  ///
  /// In en, this message translates to:
  /// **'12 hours'**
  String get freq12h;

  /// No description provided for @freq24h.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get freq24h;

  /// No description provided for @topAlign.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get topAlign;

  /// No description provided for @centerAlign.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get centerAlign;

  /// No description provided for @bottomAlign.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get bottomAlign;

  /// No description provided for @leftOffset.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get leftOffset;

  /// No description provided for @rightOffset.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get rightOffset;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @changeNow.
  ///
  /// In en, this message translates to:
  /// **'Change now'**
  String get changeNow;

  /// No description provided for @calibrateButton.
  ///
  /// In en, this message translates to:
  /// **'Calibrate text centering'**
  String get calibrateButton;

  /// No description provided for @permissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper permission'**
  String get permissionTitle;

  /// No description provided for @permissionMessage.
  ///
  /// In en, this message translates to:
  /// **'This app needs permission to set wallpaper on your device.\n\nIt will only be used when you activate \"Change now\" or automatic updates.'**
  String get permissionMessage;

  /// Status message while wallpaper is being generated
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get generating;

  /// Status message after wallpaper is updated successfully
  ///
  /// In en, this message translates to:
  /// **'Wallpaper updated: {citation}'**
  String wallpaperUpdated(String citation);

  /// No description provided for @generatingError.
  ///
  /// In en, this message translates to:
  /// **'Error generating wallpaper'**
  String get generatingError;

  /// No description provided for @selectCategoryStatus.
  ///
  /// In en, this message translates to:
  /// **'Select at least one category'**
  String get selectCategoryStatus;

  /// No description provided for @calibrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Calibrate'**
  String get calibrationTitle;

  /// No description provided for @calibrationInstructions.
  ///
  /// In en, this message translates to:
  /// **'Adjust the slider to crop the image edges, then apply and verify on your home screen.'**
  String get calibrationInstructions;

  /// No description provided for @cropInsetLabel.
  ///
  /// In en, this message translates to:
  /// **'Crop inset'**
  String get cropInsetLabel;

  /// No description provided for @cropInsetDesc.
  ///
  /// In en, this message translates to:
  /// **'Adjust the crop area until the text is centered.'**
  String get cropInsetDesc;

  /// Button label to apply and verify wallpaper calibration
  ///
  /// In en, this message translates to:
  /// **'Apply & verify'**
  String get applyVerify;

  /// No description provided for @saveCalibration.
  ///
  /// In en, this message translates to:
  /// **'Save calibration'**
  String get saveCalibration;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset to 0'**
  String get reset;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @categoryCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create category'**
  String get categoryCreateTitle;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty'**
  String get nameRequired;

  /// No description provided for @citationRequired.
  ///
  /// In en, this message translates to:
  /// **'Citation is required'**
  String get citationRequired;

  /// No description provided for @textRequired.
  ///
  /// In en, this message translates to:
  /// **'Text is required'**
  String get textRequired;

  /// No description provided for @sectionScheduling.
  ///
  /// In en, this message translates to:
  /// **'Scheduling'**
  String get sectionScheduling;

  /// No description provided for @sectionSchedulingSub.
  ///
  /// In en, this message translates to:
  /// **'Set how often the wallpaper updates automatically'**
  String get sectionSchedulingSub;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @sectionAppearanceSub.
  ///
  /// In en, this message translates to:
  /// **'Adjust text position on the wallpaper'**
  String get sectionAppearanceSub;

  /// No description provided for @sectionCategoriesSub.
  ///
  /// In en, this message translates to:
  /// **'Choose which verses to display'**
  String get sectionCategoriesSub;

  /// No description provided for @sectionActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get sectionActions;

  /// No description provided for @sectionActionsSub.
  ///
  /// In en, this message translates to:
  /// **'Change wallpaper or calibrate centering'**
  String get sectionActionsSub;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Vers Reminder helps you memorize Bible verses by displaying them as wallpaper on your home screen.'**
  String get aboutDescription;

  /// No description provided for @aboutContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get aboutContact;

  /// No description provided for @aboutShare.
  ///
  /// In en, this message translates to:
  /// **'Share app'**
  String get aboutShare;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// Subtitle shown when an update is available
  ///
  /// In en, this message translates to:
  /// **'Update available: {version}'**
  String updateAvailable(String version);

  /// Confirmation before downloading an update
  ///
  /// In en, this message translates to:
  /// **'A new version ({version}) is available. Download (approx. {size})? It preserves your wallpapers and settings.'**
  String downloadUpdateConfirm(String version, String size);

  /// No description provided for @downloadUpdate.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadUpdate;

  /// No description provided for @installNow.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get installNow;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date'**
  String get upToDate;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates'**
  String get updateCheckFailed;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download the update'**
  String get updateDownloadFailed;

  /// No description provided for @updateInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t install the update'**
  String get updateInstallFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @downloadingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Downloading update...'**
  String get downloadingUpdate;

  /// Progress percentage while downloading an update
  ///
  /// In en, this message translates to:
  /// **'Downloading update... {percentage}%'**
  String updateDownloadProgress(String percentage);

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete. Install the update now?'**
  String get downloadComplete;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @noWallpaper.
  ///
  /// In en, this message translates to:
  /// **'No wallpaper yet. Tap to generate your first one.'**
  String get noWallpaper;

  /// No description provided for @restoreOriginalWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Restore original wallpaper'**
  String get restoreOriginalWallpaper;

  /// No description provided for @restoreOriginalWallpaperSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore the wallpaper that was active before using Vers Reminder'**
  String get restoreOriginalWallpaperSubtitle;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore wallpaper?'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will replace your current wallpaper with the original one.'**
  String get restoreConfirmMessage;

  /// No description provided for @restoreConfirmOk.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreConfirmOk;

  /// No description provided for @restoreConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get restoreConfirmCancel;

  /// No description provided for @restoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Original wallpaper restored'**
  String get restoreSuccess;

  /// No description provided for @restoreError.
  ///
  /// In en, this message translates to:
  /// **'Could not restore wallpaper'**
  String get restoreError;

  /// No description provided for @noBackupAvailable.
  ///
  /// In en, this message translates to:
  /// **'No backup available'**
  String get noBackupAvailable;

  /// No description provided for @backgroundSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get backgroundSourceLabel;

  /// No description provided for @backgroundSourceApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get backgroundSourceApp;

  /// No description provided for @backgroundSourceMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get backgroundSourceMine;

  /// No description provided for @pickBackgroundImage.
  ///
  /// In en, this message translates to:
  /// **'Choose background image'**
  String get pickBackgroundImage;

  /// No description provided for @replaceBackgroundImage.
  ///
  /// In en, this message translates to:
  /// **'Replace image'**
  String get replaceBackgroundImage;

  /// No description provided for @backgroundSelected.
  ///
  /// In en, this message translates to:
  /// **'Background image selected'**
  String get backgroundSelected;

  /// No description provided for @backgroundPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open image picker'**
  String get backgroundPickFailed;

  /// No description provided for @currentWallpaperLabel.
  ///
  /// In en, this message translates to:
  /// **'Current wallpaper'**
  String get currentWallpaperLabel;

  /// Caption on the Home wallpaper card showing when it was last updated
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String updatedAtLabel(String time);

  /// Text shared when the user taps the share action on Home
  ///
  /// In en, this message translates to:
  /// **'Download Vers Reminder: {url}'**
  String shareApp(String url);

  /// No description provided for @emailCopied.
  ///
  /// In en, this message translates to:
  /// **'Email copied to clipboard'**
  String get emailCopied;

  /// Compact relative/frequency time unit for minute values
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String timeMinutes(int n);

  /// Compact relative/frequency time unit for hour values
  ///
  /// In en, this message translates to:
  /// **'{n} h'**
  String timeHours(int n);

  /// No description provided for @previewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewLabel;

  /// Single horizontal-offset caption resolved from the slider value's sign
  ///
  /// In en, this message translates to:
  /// **'Offset: {direction} {value}'**
  String offsetLabel(String direction, String value);

  /// No description provided for @disabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabledLabel;
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
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
