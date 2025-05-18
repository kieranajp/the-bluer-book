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
