CREATE TABLE recipes (
    uuid UUID PRIMARY KEY,
    name VARCHAR NOT NULL,
    description TEXT,
    timing INTERVAL,
    serving_size SMALLINT,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE steps (
    uuid UUID PRIMARY KEY,
    recipe_id UUID REFERENCES recipes(uuid),
    step_index SMALLINT,
    description TEXT,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE ingredients (
    uuid UUID PRIMARY KEY,
    name VARCHAR NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE recipe_ingredients (
    recipe_id UUID REFERENCES recipes(uuid),
    ingredient_id UUID REFERENCES ingredients(uuid),
    unit VARCHAR,
    quantity DOUBLE PRECISION,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    PRIMARY KEY (recipe_id, ingredient_id)
);
