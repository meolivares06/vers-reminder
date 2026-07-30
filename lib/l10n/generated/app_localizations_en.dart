// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

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
  String get autoChange => 'Auto change wallpaper';

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
  String get sectionScheduling => 'Scheduling';

  @override
  String get sectionSchedulingSub =>
      'Set how often the wallpaper updates automatically';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionAppearanceSub => 'Adjust text position on the wallpaper';

  @override
  String get sectionCategoriesSub => 'Choose which verses to display';

  @override
  String get sectionActions => 'Actions';

  @override
  String get sectionActionsSub => 'Change wallpaper or calibrate centering';

  @override
  String get selectAll => 'Select all';

  @override
  String get clearAll => 'Clear all';

  @override
  String get sectionAbout => 'About';

  @override
  String get aboutDescription =>
      'Vers Reminder helps you memorize Bible verses by displaying them as wallpaper on your home screen.';

  @override
  String get aboutContact => 'Contact';

  @override
  String get aboutVersion => 'Version 1.0.0';

  @override
  String get homeTab => 'Home';

  @override
  String get noWallpaper => 'No wallpaper yet. Tap to generate your first one.';
}
