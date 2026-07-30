# Delta for wallpaper-gen

## ADDED Requirements

### Requirement: Extractable Composite Pipeline

The system MUST extract compositing from file-writing. A private `_composite()` method MUST accept source image bytes and target dimensions, apply the 40% dark overlay, render and composite verse text, and return the composited result as `Uint8List` (PNG-encoded bytes). The existing `_render()` method SHALL call `_composite()` then write the returned bytes to a file. The compositing logic MUST remain visually identical to the original inline implementation.

#### Scenario: Composite returns valid PNG bytes

- GIVEN valid background image bytes and target dimensions
- WHEN `_composite()` is called
- THEN it MUST return `Uint8List` containing a valid PNG image
- AND the returned image MUST have the requested width and height

#### Scenario: Corrupt bytes returns null

- GIVEN corrupt background image bytes
- WHEN `_composite()` is called
- THEN it MUST return null
- AND no file is written

### Requirement: Preview Renderer

The system MUST provide a `renderPreview()` method that calls `_composite()` at approximately one-quarter screen resolution. The method MUST return `Uint8List?` (PNG bytes) without writing to disk. The preview MUST be visually identical to a full render at the same settings, differing only in resolution. `renderPreview()` SHALL accept the same layout parameters (`horizontalOffset`, `verticalAlignment`, `fontScale`, `calibratedInset`) as the full render pipeline.

#### Scenario: Preview returns at lower resolution

- GIVEN screen dimensions 1080×2340
- WHEN `renderPreview()` is called
- THEN the returned width MUST be approximately 270 (¼)
- AND the returned height MUST be approximately 585 (¼)
- AND the bytes MUST decode to a valid PNG

#### Scenario: Preview matches full render compositing

- GIVEN the same background image and verse
- WHEN both `renderPreview()` and `_render()` are called with identical parameters
- THEN the overlay opacity, text content, and compositing order MUST be identical
- AND only the resolution SHALL differ

#### Scenario: Preview returns null when background fails

- GIVEN the background image source returns null
- WHEN `renderPreview()` is called
- THEN it MUST return null
- AND the existing `_render()` error path MUST be preserved unchanged
