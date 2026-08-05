// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'package:vers_reminder/shared/l10n/generated/app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Vers Reminder';

  @override
  String get verseListTitle => 'Verses';

  @override
  String get addVerse => 'Add verse';

  @override
  String get editVerse => 'Edit verse';

  @override
  String get newVerse => 'New verse';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get confirmDelete => 'Delete verse?';

  @override
  String get confirmDeleteBody => 'Are you sure you want to delete this verse?';

  @override
  String get confirm => 'Yes, delete';

  @override
  String confirmDeleteCitation(String citation) {
    return 'Delete \"$citation\"?';
  }

  @override
  String get citation => 'Citation';

  @override
  String get text => 'Text';

  @override
  String get textEs => 'Text (Spanish)';

  @override
  String get textPt => 'Text (Portuguese)';

  @override
  String get categoriesLabel => 'Categories';

  @override
  String get categoryNameLabel => 'Category name';

  @override
  String get citationHint => 'e.g. John 3:16';

  @override
  String get selectCategory => 'Select category';

  @override
  String get addCategory => 'Add category';

  @override
  String get newCategoryName => 'New category name';

  @override
  String get selectAtLeastOneCategory => 'Select at least one category';

  @override
  String get noVerses => 'No verses yet';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get spanish => 'Spanish';

  @override
  String get portuguese => 'Portuguese';

  @override
  String get autoChange => 'Auto-rotate';

  @override
  String get freq15min => '15 min';

  @override
  String get freq30min => '30 min';

  @override
  String get freq1h => '1 hour';

  @override
  String get freq3h => '3 hours';

  @override
  String get freq6h => '6 hours';

  @override
  String get freq12h => '12 hours';

  @override
  String get freq24h => '24 hours';

  @override
  String get topAlign => 'Top';

  @override
  String get centerAlign => 'Center';

  @override
  String get bottomAlign => 'Bottom';

  @override
  String get leftOffset => 'Left';

  @override
  String get rightOffset => 'Right';

  @override
  String get fontSize => 'Font size';

  @override
  String get changeNow => 'Change now';

  @override
  String get calibrateButton => 'Calibrate text centering';

  @override
  String get permissionTitle => 'Wallpaper permission';

  @override
  String get permissionMessage =>
      'This app needs permission to set wallpaper on your device.\n\nIt will only be used when you activate \"Change now\" or automatic updates.';

  @override
  String get generating => 'Generating...';

  @override
  String wallpaperUpdated(String citation) {
    return 'Wallpaper updated: $citation';
  }

  @override
  String get generatingError => 'Error generating wallpaper';

  @override
  String get selectCategoryStatus => 'Select at least one category';

  @override
  String get calibrationTitle => 'Calibrate';

  @override
  String get calibrationInstructions =>
      'Adjust the slider to crop the image edges, then apply and verify on your home screen.';

  @override
  String get cropInsetLabel => 'Crop inset';

  @override
  String get cropInsetDesc =>
      'Adjust the crop area until the text is centered.';

  @override
  String get applyVerify => 'Apply & verify';

  @override
  String get saveCalibration => 'Save calibration';

  @override
  String get reset => 'Reset to 0';

  @override
  String get create => 'Create';

  @override
  String get categoryCreateTitle => 'Create category';

  @override
  String get nameRequired => 'Name cannot be empty';

  @override
  String get citationRequired => 'Citation is required';

  @override
  String get textRequired => 'Text is required';

  @override
  String get sectionScheduling => 'Rotation';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionActions => 'Actions';

  @override
  String get selectAll => 'All';

  @override
  String get clearAll => 'None';

  @override
  String get sectionAbout => 'About';

  @override
  String get aboutDescription =>
      'Vers Reminder helps you memorize Bible verses by displaying them as wallpaper on your home screen.';

  @override
  String get aboutContact => 'Contact';

  @override
  String get aboutShare => 'Share app';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String updateAvailable(String version) {
    return 'Update available: $version';
  }

  @override
  String downloadUpdateConfirm(String version, String size) {
    return 'A new version ($version) is available. Download (approx. $size)? It preserves your wallpapers and settings.';
  }

  @override
  String get downloadUpdate => 'Download';

  @override
  String get installNow => 'Install';

  @override
  String get upToDate => 'You\'re up to date';

  @override
  String get updateCheckFailed => 'Couldn\'t check for updates';

  @override
  String get updateDownloadFailed => 'Couldn\'t download the update';

  @override
  String get updateInstallFailed => 'Couldn\'t install the update';

  @override
  String get retry => 'Retry';

  @override
  String get downloadingUpdate => 'Downloading update...';

  @override
  String updateDownloadProgress(String percentage) {
    return 'Downloading update... $percentage%';
  }

  @override
  String get downloadComplete => 'Download complete. Install the update now?';

  @override
  String get homeTab => 'Home';

  @override
  String get noWallpaper => 'Tap to create your first wallpaper';

  @override
  String get restoreOriginalWallpaper => 'Restore original wallpaper';

  @override
  String get restoreOriginalWallpaperSubtitle =>
      'Restore the wallpaper that was active before using Vers Reminder';

  @override
  String get restoreConfirmTitle => 'Restore wallpaper?';

  @override
  String get restoreConfirmMessage =>
      'This will replace your current wallpaper with the original one.';

  @override
  String get restoreConfirmOk => 'Restore';

  @override
  String get restoreConfirmCancel => 'Cancel';

  @override
  String get restoreSuccess => 'Original wallpaper restored';

  @override
  String get restoreError => 'Could not restore wallpaper';

  @override
  String get noBackupAvailable => 'No backup available';

  @override
  String get backgroundSourceLabel => 'Background';

  @override
  String get backgroundSourceApp => 'App';

  @override
  String get backgroundSourceMine => 'Mine';

  @override
  String get pickBackgroundImage => 'Choose background image';

  @override
  String get replaceBackgroundImage => 'Replace image';

  @override
  String get backgroundSelected => 'Background image selected';

  @override
  String get backgroundPickFailed => 'Could not open image picker';

  @override
  String get currentWallpaperLabel => 'Your wallpaper';

  @override
  String updatedAtLabel(String time) {
    return '$time ago';
  }

  @override
  String shareApp(String url) {
    return 'Download Vers Reminder: $url';
  }

  @override
  String get emailCopied => 'Email copied to clipboard';

  @override
  String timeMinutes(int n) {
    return '$n min';
  }

  @override
  String timeHours(int n) {
    return '$n h';
  }

  @override
  String get previewLabel => 'Preview';

  @override
  String offsetLabel(String direction, String value) {
    return 'Offset: $direction $value';
  }

  @override
  String get disabledLabel => 'Disabled';
}
