# Resource Disposal Specification

## Purpose

Guarantee deterministic cleanup of Flutter native resources (PictureRecorder, Canvas, TextPainter) created during wallpaper compositing, regardless of exception propagation.

## Requirements

### Requirement: PictureRecorder + Canvas Disposal Guarantee

The system MUST dispose every `PictureRecorder` and its associated `Canvas` created during `_compositeCanvas` on all code paths. Disposal MUST execute in a `finally` block that runs after the compositing try block completes — whether by normal return or exception propagation.

#### Scenario: Successful composite disposes recorder

- GIVEN a valid background image and verse text
- WHEN `_compositeCanvas` completes without exception
- THEN the `PictureRecorder` MUST be disposed via `finally`
- AND the `Canvas` MUST be released

#### Scenario: Draw exception still disposes recorder

- GIVEN compositing is in progress
- WHEN a draw operation throws an exception
- THEN the `PictureRecorder` MUST be disposed via `finally`
- AND the original exception MUST propagate to the caller unchanged

#### Scenario: Dispose exception does not hide render exception

- GIVEN a render exception occurred inside the try block
- WHEN the `finally` block's dispose also throws
- THEN the original render exception MUST propagate (not the dispose exception)

### Requirement: TextPainter Disposal Guarantee

The system MUST dispose `TextPainter` and `citationPainter` instances on all code paths within the composite pipeline. TextPainters created as part of verse layout MUST be scoped to a protected block that guarantees disposal before the enclosing method exits, regardless of where exceptions occur.

#### Scenario: Successful composite disposes text painters

- GIVEN a verse and citation are laid out successfully
- WHEN compositing completes without exception
- THEN `textPainter` MUST be disposed
- AND `citationPainter` MUST be disposed

#### Scenario: Exception between painter creation and compositing still disposes

- GIVEN `textPainter` is created and laid out
- WHEN a subsequent canvas operation throws before `textPainter.dispose()` is reached inline
- THEN `textPainter` MUST be disposed by the enclosing protected block
- AND `citationPainter` MUST be disposed if already created

#### Scenario: Painters not yet created when exception occurs

- GIVEN no `TextPainter` has been constructed yet
- WHEN an exception occurs before painter creation
- THEN the disposal guard MUST NOT throw a null-reference error
