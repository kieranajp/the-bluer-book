-- +goose Up
-- Consolidate duplicate units of measure.
-- This is a one-way data migration: duplicates are merged and cannot be unmerged.

-- Step 1: Normalize all unit names to lowercase trimmed
UPDATE units SET name = LOWER(TRIM(name)), updated_at = now();

-- Step 2: Null out recipe_ingredient.unit_id for empty-string units
UPDATE recipe_ingredient ri
SET unit_id = NULL
FROM units u
WHERE ri.unit_id = u.uuid AND u.name = '';

-- Step 3: Remap all recipe_ingredient FKs from duplicate units to the canonical (oldest) unit per name
WITH canonical AS (
  SELECT DISTINCT ON (name) uuid AS canonical_uuid, name
  FROM units
  WHERE name != ''
  ORDER BY name, created_at ASC
),
duplicates AS (
  SELECT u.uuid AS dup_uuid, c.canonical_uuid
  FROM units u
  JOIN canonical c ON u.name = c.name
  WHERE u.uuid != c.canonical_uuid
)
UPDATE recipe_ingredient ri
SET unit_id = d.canonical_uuid
FROM duplicates d
WHERE ri.unit_id = d.dup_uuid;

-- Step 4: Delete non-canonical and empty-string unit rows
DELETE FROM units
WHERE uuid NOT IN (
  SELECT DISTINCT ON (name) uuid
  FROM units
  WHERE name != ''
  ORDER BY name, created_at ASC
);

-- Step 5: Add unique constraint on name
ALTER TABLE units ADD CONSTRAINT units_name_unique UNIQUE (name);
