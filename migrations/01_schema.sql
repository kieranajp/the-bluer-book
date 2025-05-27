-- Drop existing schema objects
DROP TABLE IF EXISTS photos CASCADE;
DROP TABLE IF EXISTS recipe_label CASCADE;
DROP TABLE IF EXISTS recipe_ingredient CASCADE;
DROP TABLE IF EXISTS steps CASCADE;
DROP TABLE IF EXISTS labels CASCADE;
DROP TABLE IF EXISTS units CASCADE;
DROP TABLE IF EXISTS ingredients CASCADE;
DROP TABLE IF EXISTS recipes CASCADE;

-- Install pgcrypto for UUID generation
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create lookup tables
CREATE TABLE ingredients (
  uuid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR UNIQUE NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE units (
  uuid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR NOT NULL,
  abbreviation VARCHAR,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE labels (
  uuid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR NOT NULL,
  color VARCHAR,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Create main recipe table
CREATE TABLE recipes (
  id TEXT PRIMARY KEY,
  name VARCHAR NOT NULL,
  description TEXT,
  cook_time INTERVAL,
  prep_time INTERVAL,
  servings SMALLINT,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now(),
  main_photo_id UUID
);

-- Create dependent tables
CREATE TABLE steps (
  uuid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id TEXT REFERENCES recipes(id),
  step_order SMALLINT NOT NULL,
  description TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE recipe_ingredient (
  recipe_id TEXT REFERENCES recipes(id),
  ingredient_id UUID REFERENCES ingredients(uuid),
  unit_id UUID REFERENCES units(uuid),
  quantity DOUBLE PRECISION,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (recipe_id, ingredient_id)
);

CREATE TABLE recipe_label (
  recipe_id TEXT REFERENCES recipes(id),
  label_id UUID REFERENCES labels(uuid),
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (recipe_id, label_id)
);

CREATE TABLE photos (
  uuid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  url VARCHAR NOT NULL,
  entity_type VARCHAR NOT NULL, -- 'recipe', 'step', or 'ingredient'
  entity_id TEXT NOT NULL,      -- foreign key target (text or UUID)
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);