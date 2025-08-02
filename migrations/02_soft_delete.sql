-- Add archived_at column to recipes table for soft delete functionality
ALTER TABLE recipes ADD COLUMN archived_at TIMESTAMP NULL;

-- Add index for efficient queries filtering out archived records
-- This partial index only includes rows where archived_at IS NULL (active records)
CREATE INDEX idx_recipes_archived_at_null ON recipes(archived_at) WHERE archived_at IS NULL;

-- Add index for archived records queries (admin functions)
-- This partial index only includes rows where archived_at IS NOT NULL (archived records)
CREATE INDEX idx_recipes_archived_at_not_null ON recipes(archived_at) WHERE archived_at IS NOT NULL;

-- Add composite index for efficient searching within active records
CREATE INDEX idx_recipes_active_search ON recipes(created_at DESC) WHERE archived_at IS NULL;
