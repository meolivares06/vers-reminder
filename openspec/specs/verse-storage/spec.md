# Verse Storage Specification

## Purpose

Persist and retrieve Bible verses, categories, and their many-to-many relationships using local SQLite storage. Provides automatic seed data loading on first launch so the app is immediately useful.

## Requirements

### Requirement: Schema Definition

The system SHALL define three SQLite tables: `verses` (id, textEs, textPt, citation, createdAt), `categories` (id, name), and `verse_categories` (verseId, categoryId) as a junction table. The junction table SHALL enforce foreign key constraints with CASCADE deletes.

#### Scenario: Creates tables on database open

- GIVEN the database is being opened for the first time
- WHEN `onCreate` is called
- THEN tables `verses`, `categories`, and `verse_categories` exist with the defined schema

#### Scenario: Cascade delete removes junction rows

- GIVEN a verse is linked to two categories via `verse_categories`
- WHEN the verse is deleted
- THEN the corresponding junction rows are also deleted
- AND the categories remain untouched

### Requirement: Seed Data Loading

The system MUST load seed verses from `assets/seed/verses.json` on first launch if the `verses` table is empty. The seed file SHALL contain verses in both ES (RVR1960) and PT (ARC 2009) across 16 fixed categories with approximately 3 verses each. After seeding, the system SHALL mark the database as initialized to prevent re-seeding.

#### Scenario: Seeds on first launch

- GIVEN the app launches for the first time and `verses` is empty
- WHEN the database initialization completes
- THEN all verses (ES + PT) from the JSON file are available in the `verses` table
- AND the 16 categories are created in the `categories` table

#### Scenario: Skips seed if data exists

- GIVEN the app launches and verses already exist in the database
- WHEN the database opens
- THEN no seed data is loaded and existing data is preserved

### Requirement: CRUD Operations

The system MUST provide create, read, update, and delete operations for verses and categories. Update SHALL replace the existing record entirely, preserving its ID. Delete SHALL remove the record and all associated junction rows via CASCADE.

#### Scenario: Creates and retrieves a verse

- GIVEN the database is ready
- WHEN a new verse with textEs, textPt, citation, and two category IDs is inserted
- THEN the verse is retrievable by ID with its associated categories

#### Scenario: Updates an existing verse

- GIVEN a verse exists with text "A" linked to category 1
- WHEN the verse text is updated to "B" and category link is changed to category 2
- THEN reading the verse returns text "B" linked to category 2

#### Scenario: Deletes a verse

- GIVEN a verse exists linked to two categories
- WHEN the verse is deleted
- THEN the verse no longer appears in any query
- AND the junction table has no orphaned rows for that verse

### Requirement: Query by Category

The system MUST support querying all verses grouped by category, returning only categories that have at least one verse in the current locale.

#### Scenario: Groups verses by category

- GIVEN three verses exist across two categories
- WHEN the grouped query runs
- THEN two groups are returned, each containing their respective verses

#### Scenario: Handles locale fallback

- GIVEN a verse has textEs populated and textPt is not available
- WHEN the app locale is PT
- THEN the system displays textEs as fallback
- AND the user still sees the verse content
