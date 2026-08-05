import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages visual appearance settings: font scale, layout offsets,
/// alignment, and wallpaper background source selection.
///
/// Pure settings CRUD — no emissions via EventBus. Persists everything
/// to SharedPreferences.
class AppearanceSettings extends ChangeNotifier {
  double _fontScale = 1.0;
  int _horizontalOffset = 0;
  String _verticalAlignment = 'center';
  int _calibratedInset = 0;
  bool _useMyWallpaper = false;
  String? _userBackgroundPath;

  double get fontScale => _fontScale;
  int get horizontalOffset => _horizontalOffset;
  String get verticalAlignment => _verticalAlignment;
  int get calibratedInset => _calibratedInset;
  bool get useMyWallpaper => _useMyWallpaper;
  String? get userBackgroundPath => _userBackgroundPath;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _horizontalOffset = prefs.getInt('horizontal_offset') ?? 0;
    _verticalAlignment = prefs.getString('vertical_alignment') ?? 'center';
    _calibratedInset = prefs.getInt('calibrated_inset') ?? 0;
    _fontScale = prefs.getDouble('font_scale') ?? 1.0;
    _useMyWallpaper = prefs.getBool('use_my_wallpaper') ?? false;
    _userBackgroundPath = prefs.getString('user_background_path');
  }

  Future<void> setFontScale(double value) async {
    _fontScale = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_scale', value);
    notifyListeners();
  }

  Future<void> setHorizontalOffset(int value) async {
    _horizontalOffset = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('horizontal_offset', value);
    notifyListeners();
  }

  Future<void> setVerticalAlignment(String value) async {
    _verticalAlignment = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vertical_alignment', value);
    notifyListeners();
  }

  Future<void> setCalibratedInset(int value) async {
    _calibratedInset = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('calibrated_inset', value);
    notifyListeners();
  }

  Future<void> setUseMyWallpaper(bool value) async {
    _useMyWallpaper = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_my_wallpaper', value);
    notifyListeners();
  }

  Future<void> setUserBackgroundPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('user_background_path', path);
    } else {
      await prefs.remove('user_background_path');
    }
    _userBackgroundPath = path;
    notifyListeners();
  }
}
