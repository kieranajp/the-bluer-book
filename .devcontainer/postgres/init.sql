-- Set error handling
\set ON_ERROR_STOP on

-- Debug: List files before running migrations
\echo 'Files in /docker-entrypoint-initdb.d/:'
\! ls -la /docker-entrypoint-initdb.d/

-- Run migrations in order
\echo 'Running schema migration...'
\echo 'Running extensions...'
\i /docker-entrypoint-initdb.d/01_extensions.sql
\echo 'Running schema...'
\i /docker-entrypoint-initdb.d/02_schema.sql
\echo 'Running seed data...'
\i /docker-entrypoint-initdb.d/03_seed_data.sql

-- Debug: List tables after migrations
\echo 'Tables in database:'
\dt

-- Verify data was loaded
DO $$
BEGIN
    -- Check if we have seed data
    IF NOT EXISTS (SELECT 1 FROM units LIMIT 1) THEN
        RAISE EXCEPTION 'Seed data not loaded properly';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM ingredients LIMIT 1) THEN
        RAISE EXCEPTION 'Seed data not loaded properly';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM recipes LIMIT 1) THEN
        RAISE EXCEPTION 'Seed data not loaded properly';
    END IF;
END $$; 