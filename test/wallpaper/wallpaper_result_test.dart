import 'package:flutter_test/flutter_test.dart';
import 'package:vers_reminder/wallpaper/domain/wallpaper_result.dart';

void main() {
  group('WallpaperResult', () {
    group('WallpaperResultSuccess', () {
      test('creates success with path and citation', () {
        final result = WallpaperResultSuccess(
          '/tmp/test.png',
          'Verse text',
          'Juan 3:16',
        );
        expect(result.wallpaperPath, '/tmp/test.png');
        expect(result.verseText, 'Verse text');
        expect(result.citation, 'Juan 3:16');
      });

      test('creates success with only path', () {
        final result = WallpaperResultSuccess('/tmp/test.png');
        expect(result.wallpaperPath, '/tmp/test.png');
        expect(result.verseText, isNull);
        expect(result.citation, isNull);
      });

      test('is a WallpaperResult', () {
        final result = WallpaperResultSuccess('/tmp/test.png');
        expect(result, isA<WallpaperResult>());
      });
    });

    group('WallpaperResultError', () {
      test('creates error with noVersesForLocale reason', () {
        final result =
            WallpaperResultError(WallpaperErrorReason.noVersesForLocale);
        expect(result.reason, WallpaperErrorReason.noVersesForLocale);
      });

      test('creates error with backgroundMissing reason', () {
        final result =
            WallpaperResultError(WallpaperErrorReason.backgroundMissing);
        expect(result.reason, WallpaperErrorReason.backgroundMissing);
      });

      test('creates error with storageFailure reason', () {
        final result =
            WallpaperResultError(WallpaperErrorReason.storageFailure);
        expect(result.reason, WallpaperErrorReason.storageFailure);
      });

      test('creates error with renderFailed reason', () {
        final result =
            WallpaperResultError(WallpaperErrorReason.renderFailed);
        expect(result.reason, WallpaperErrorReason.renderFailed);
      });

      test('is a WallpaperResult', () {
        final result =
            WallpaperResultError(WallpaperErrorReason.storageFailure);
        expect(result, isA<WallpaperResult>());
      });
    });

    group('pattern matching', () {
      test('pattern matches on success', () {
        final WallpaperResult result =
            WallpaperResultSuccess('/tmp/test.png', null, 'Juan 3:16');
        final message = switch (result) {
          WallpaperResultSuccess(:final citation) =>
            'Success: ${citation ?? 'unknown'}',
          WallpaperResultError(:final reason) => 'Error: $reason',
        };
        expect(message, 'Success: Juan 3:16');
      });

      test('pattern matches on error', () {
        final WallpaperResult result =
            WallpaperResultError(WallpaperErrorReason.backgroundMissing);
        final message = switch (result) {
          WallpaperResultSuccess() => 'Success',
          WallpaperResultError(:final reason) => 'Error: $reason',
        };
        expect(message, 'Error: WallpaperErrorReason.backgroundMissing');
      });
    });
  });
}
