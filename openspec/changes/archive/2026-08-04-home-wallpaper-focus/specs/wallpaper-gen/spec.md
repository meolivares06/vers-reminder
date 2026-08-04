# Delta for Wallpaper Generation

## ADDED Requirements

### Requirement: Verse Typography — EB Garamond Italic

The verse text rendered in the wallpaper composite SHALL use the EB Garamond typeface with `FontStyle.italic`. This MUST apply to all font-size tiers in the paint pass.

#### Scenario: Verse renders italic

- GIVEN a valid background image and verse
- WHEN the wallpaper image is composited
- THEN the verse text uses EB Garamond with italic style

#### Scenario: No non-italic verse escape

- GIVEN a verse being composited at any font-size tier
- WHEN the TextPainter renders the verse
- THEN the resolved `TextStyle.fontStyle` MUST be `FontStyle.italic`

### Requirement: Citation Typography — Sans-Serif Uppercase with Gold Rule

The verse citation SHALL render in a sans-serif typeface, with `toUpperCase()` transformation and `letterSpacing`. A small gold rule line using `colorScheme.secondary` SHALL be drawn above the citation text on the canvas.

#### Scenario: Citation renders with contrast styling

- GIVEN a composited wallpaper with verse and citation
- WHEN the image is generated
- THEN citation text is sans-serif, uppercase, and letter-spaced
- AND a gold rule line appears above the citation

#### Scenario: Citation styling independent of verse

- GIVEN the same wallpaper composite
- WHEN rendered
- THEN verse remains EB Garamond italic
- AND citation sans-serif styling does not leak into verse text

### Requirement: Measurement-Paint Typographic Parity

The `_resolveFontSize` measurement TextStyles MUST mirror the paint TextStyles exactly — including `fontFamily`, `fontStyle`, `letterSpacing`, and capitalization — so that the computed font size does not drift from what renders.

#### Scenario: Measurement matches paint for verse

- GIVEN a verse being sized by `_resolveFontSize`
- WHEN the measurement `TextStyle` is constructed
- THEN it MUST include `fontFamily: 'EB Garamond'` and `fontStyle: FontStyle.italic`

#### Scenario: Measurement matches paint for citation

- GIVEN a citation being sized by `_resolveFontSize`
- WHEN the measurement `TextStyle` is constructed
- THEN it MUST use the sans-serif family with `letterSpacing`
- AND uppercase width calculation MUST NOT cause sizing overflow

#### Scenario: No sizing regression after style change

- GIVEN an existing verse that fit at a known resolved font size before the typography change
- WHEN italic measurement is applied
- THEN the resolved font size SHALL be within 1px of the pre-change value
- OR the size SHALL be recalculated downward to prevent text overflow
