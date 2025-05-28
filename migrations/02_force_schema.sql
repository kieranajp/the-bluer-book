-- Drop existing tables if they exist
DROP TABLE IF EXISTS photos CASCADE;
DROP TABLE IF EXISTS recipe_label CASCADE;
DROP TABLE IF EXISTS recipe_ingredient CASCADE;
DROP TABLE IF EXISTS steps CASCADE;
DROP TABLE IF EXISTS recipes CASCADE;
DROP TABLE IF EXISTS labels CASCADE;
DROP TABLE IF EXISTS ingredients CASCADE;
DROP TABLE IF EXISTS units CASCADE;

-- Create lookup tables
CREATE TABLE units (
  uuid UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR NOT NULL,
  abbreviation VARCHAR,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE ingredients (
  uuid UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR UNIQUE NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE labels (
  uuid UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR NOT NULL,
  color VARCHAR,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Create main recipe table
CREATE TABLE recipes (
  uuid UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
  uuid UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipe_id UUID REFERENCES recipes(uuid) ON DELETE CASCADE,
  step_order SMALLINT NOT NULL,
  description TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE recipe_ingredient (
  recipe_id UUID REFERENCES recipes(uuid) ON DELETE CASCADE,
  ingredient_id UUID REFERENCES ingredients(uuid) ON DELETE CASCADE,
  unit_id UUID REFERENCES units(uuid) ON DELETE SET NULL,
  quantity DOUBLE PRECISION,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (recipe_id, ingredient_id)
);

CREATE TABLE recipe_label (
  recipe_id UUID REFERENCES recipes(uuid) ON DELETE CASCADE,
  label_id UUID REFERENCES labels(uuid) ON DELETE CASCADE,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (recipe_id, label_id)
);

CREATE TABLE photos (
  uuid UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  url VARCHAR NOT NULL,
  entity_type entity_type NOT NULL,
  entity_id UUID NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
); 