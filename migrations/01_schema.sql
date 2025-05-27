-- Create lookup tables
CREATE TABLE ingredients (
  uuid UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR UNIQUE NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE units (
  uuid UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR NOT NULL,
  abbreviation VARCHAR,
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
  recipe_id UUID REFERENCES recipes(uuid),
  step_order SMALLINT NOT NULL,
  description TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE recipe_ingredient (
  recipe_id UUID REFERENCES recipes(uuid),
  ingredient_id UUID REFERENCES ingredients(uuid),
  unit_id UUID REFERENCES units(uuid),
  quantity DOUBLE PRECISION,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (recipe_id, ingredient_id)
);

CREATE TABLE recipe_label (
  recipe_id UUID REFERENCES recipes(uuid),
  label_id UUID REFERENCES labels(uuid),
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (recipe_id, label_id)
);

CREATE TYPE entity_type AS ENUM ('recipe', 'step', 'ingredient');
CREATE TABLE photos (
  uuid UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  url VARCHAR NOT NULL,
  entity_type entity_type NOT NULL, -- 'recipe', 'step', or 'ingredient'
  entity_id UUID NOT NULL,      -- foreign key target
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);
