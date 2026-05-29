-- +goose Up
-- Introduce typed labels (course / cuisine / diet / method) and clean out the
-- existing label sludge: ingestion metadata, opinion tags, ingredient-as-tag
-- singletons, case-collision duplicates. After this migration every label has
-- a type and a canonical lowercase snake_case name; recipes that used any of
-- the legacy aliases are re-pointed at the canonical replacement(s).

ALTER TABLE labels ADD COLUMN type TEXT;

CREATE TEMP TABLE label_mapping (
    pattern  TEXT NOT NULL,
    new_type TEXT NOT NULL,
    new_name TEXT NOT NULL,
    PRIMARY KEY (pattern, new_type, new_name)
) ON COMMIT DROP;

INSERT INTO label_mapping (pattern, new_type, new_name) VALUES
    -- course
    ('main course',     'course', 'main'),
    ('main_course',     'course', 'main'),
    ('mains',           'course', 'main'),
    ('dinner',          'course', 'main'),
    ('pasta',           'course', 'main'),
    ('burger',          'course', 'main'),
    ('taco',            'course', 'main'),
    ('tacos',           'course', 'main'),
    ('enchiladas',      'course', 'main'),
    ('chicken-tinga',   'course', 'main'),
    ('moussaka',        'course', 'main'),
    ('arancini',        'course', 'main'),
    ('risotto',         'course', 'main'),
    ('curry',           'course', 'main'),
    ('bhuna',           'course', 'main'),
    ('falafel',         'course', 'main'),
    ('fried rice',      'course', 'main'),
    ('peri-peri',       'course', 'main'),
    ('nandos-copycat',  'course', 'main'),
    ('hot-pockets',     'course', 'main'),
    ('satay',           'course', 'main'),
    ('sandwich',        'course', 'main'),
    ('nut-roast',       'course', 'main'),
    ('dumplings',       'course', 'main'),
    ('side',            'course', 'side'),
    ('sides',           'course', 'side'),
    ('side dish',       'course', 'side'),
    ('side-dish',       'course', 'side'),
    ('dhal',            'course', 'side'),
    ('starter',         'course', 'starter'),
    ('appetizer',       'course', 'starter'),
    ('tapas',           'course', 'starter'),
    ('mezze',           'course', 'starter'),
    ('dip',             'course', 'starter'),
    ('dessert',         'course', 'dessert'),
    ('quick dessert',   'course', 'dessert'),
    ('cheesecake',      'course', 'dessert'),
    ('custard',         'course', 'dessert'),
    ('classic crumble', 'course', 'dessert'),
    ('breakfast',       'course', 'breakfast'),
    ('afternoon tea',   'course', 'breakfast'),
    ('lunch',           'course', 'lunch'),
    ('snack',           'course', 'snack'),
    ('soup',            'course', 'soup'),
    ('stew',            'course', 'stew'),
    ('tagine',          'course', 'stew'),
    ('salad',           'course', 'salad'),
    ('sauce',           'course', 'sauce'),
    ('bread',           'course', 'bread'),
    ('flatbread',       'course', 'bread'),
    ('cheese bread',    'course', 'bread'),
    ('pastry',          'course', 'pastry'),
    ('dough-balls',     'course', 'pastry'),
    ('drink',           'course', 'drink'),
    ('coffee',          'course', 'drink'),
    ('juice',           'course', 'drink'),
    ('condiment',       'course', 'condiment'),
    ('salsa',           'course', 'condiment'),

    -- cuisine
    ('british',         'cuisine', 'british'),
    ('irish',           'cuisine', 'irish'),
    ('guinness',        'cuisine', 'irish'),
    ('baileys',         'cuisine', 'irish'),
    ('st-patricks-day', 'cuisine', 'irish'),
    ('german',          'cuisine', 'german'),
    ('french',          'cuisine', 'french'),
    ('hollandaise',     'cuisine', 'french'),
    ('spanish',         'cuisine', 'spanish'),
    ('italian',         'cuisine', 'italian'),
    ('sicilian',        'cuisine', 'italian'),
    ('caprese',         'cuisine', 'italian'),
    ('pasta',           'cuisine', 'italian'),
    ('arancini',        'cuisine', 'italian'),
    ('risotto',         'cuisine', 'italian'),
    ('greek',           'cuisine', 'greek'),
    ('moussaka',        'cuisine', 'greek'),
    ('mediterranean',   'cuisine', 'mediterranean'),
    ('middle-eastern',  'cuisine', 'middle_eastern'),
    ('middle_eastern',  'cuisine', 'middle_eastern'),
    ('couscous',        'cuisine', 'middle_eastern'),
    ('falafel',         'cuisine', 'middle_eastern'),
    ('mezze',           'cuisine', 'middle_eastern'),
    ('indian',          'cuisine', 'indian'),
    ('bhuna',           'cuisine', 'indian'),
    ('dhal',            'cuisine', 'indian'),
    ('curry',           'cuisine', 'indian'),
    ('thai',            'cuisine', 'thai'),
    ('chinese',         'cuisine', 'chinese'),
    ('fried rice',      'cuisine', 'chinese'),
    ('korean',          'cuisine', 'korean'),
    ('kimchi',          'cuisine', 'korean'),
    ('japanese',        'cuisine', 'japanese'),
    ('vietnamese',      'cuisine', 'vietnamese'),
    ('indonesian',      'cuisine', 'indonesian'),
    ('satay',           'cuisine', 'indonesian'),
    ('mexican',         'cuisine', 'mexican'),
    ('taco',            'cuisine', 'mexican'),
    ('tacos',           'cuisine', 'mexican'),
    ('enchiladas',      'cuisine', 'mexican'),
    ('chicken-tinga',   'cuisine', 'mexican'),
    ('salsa',           'cuisine', 'mexican'),
    ('american',        'cuisine', 'american'),
    ('burger',          'cuisine', 'american'),
    ('moroccan',        'cuisine', 'moroccan'),
    ('tagine',          'cuisine', 'moroccan'),
    ('african',         'cuisine', 'african'),
    ('south_african',   'cuisine', 'african'),
    ('georgian',        'cuisine', 'georgian'),

    -- diet
    ('vegetarian',      'diet', 'vegetarian'),
    ('veggie',          'diet', 'vegetarian'),
    ('vegan',           'diet', 'vegan'),
    ('gluten-free',     'diet', 'gluten_free'),
    ('gluten_free',     'diet', 'gluten_free'),
    ('dairy-free',      'diet', 'dairy_free'),
    ('egg-free',        'diet', 'egg_free'),
    ('nut-free',        'diet', 'nut_free'),
    ('onion free',      'diet', 'low_fodmap'),
    ('onion_free',      'diet', 'low_fodmap'),
    ('low_fodmap',      'diet', 'low_fodmap'),
    ('low-fodmap',      'diet', 'low_fodmap'),
    ('low carb',        'diet', 'low_carb'),
    ('low-carb',        'diet', 'low_carb'),
    ('low calorie',     'diet', 'low_calorie'),
    ('low-calorie',     'diet', 'low_calorie'),
    ('low_cal',         'diet', 'low_calorie'),

    -- method
    ('slow-cooked',     'method', 'slow_cooked'),
    ('slow-cooker',     'method', 'slow_cooked'),
    ('baked',           'method', 'baked'),
    ('baking',          'method', 'baked'),
    ('grilled',         'method', 'grilled'),
    ('bbq',             'method', 'grilled'),
    ('deep fried',      'method', 'fried'),
    ('roasted',         'method', 'roasted'),
    ('roasted-vegetables', 'method', 'roasted'),
    ('raw',             'method', 'raw'),
    ('no-bake',         'method', 'no_cook'),
    ('no-cook',         'method', 'no_cook'),
    ('fermented',       'method', 'fermented'),
    ('kimchi',          'method', 'fermented'),
    ('microwave',       'method', 'microwave'),
    ('sous-vide',       'method', 'sous_vide'),
    ('stir-fry',        'method', 'stir_fry'),
    ('stir_fry',        'method', 'stir_fry');

-- Materialise canonical labels for any (type, name) pair referenced by the
-- mapping that doesn't already exist. We rely on the type column being unique
-- after the constraint is added below.
INSERT INTO labels (type, name)
SELECT DISTINCT m.new_type, m.new_name
FROM label_mapping m
WHERE NOT EXISTS (
    SELECT 1 FROM labels l
    WHERE l.type = m.new_type AND l.name = m.new_name
);

-- For every legacy (untyped) label that matches a mapping pattern, create the
-- equivalent recipe_label rows pointing at the canonical label(s). Existing
-- canonical assignments are preserved via ON CONFLICT.
INSERT INTO recipe_label (recipe_id, label_id, created_at, updated_at)
SELECT DISTINCT rl.recipe_id, canonical.uuid, NOW(), NOW()
FROM recipe_label rl
JOIN labels legacy ON legacy.uuid = rl.label_id AND legacy.type IS NULL
JOIN label_mapping m ON LOWER(legacy.name) = m.pattern
JOIN labels canonical ON canonical.type = m.new_type
                     AND canonical.name = m.new_name
ON CONFLICT (recipe_id, label_id) DO NOTHING;

-- Drop legacy recipe_label rows (anything still pointing at an untyped label
-- after the rewrite — both mapped originals and unmapped junk).
DELETE FROM recipe_label
WHERE label_id IN (SELECT uuid FROM labels WHERE type IS NULL);

-- Drop the legacy labels themselves.
DELETE FROM labels WHERE type IS NULL;

-- Lock down the new schema.
ALTER TABLE labels DROP COLUMN color;
ALTER TABLE labels ALTER COLUMN type SET NOT NULL;
ALTER TABLE labels ADD CONSTRAINT labels_type_check
    CHECK (type IN ('course', 'cuisine', 'diet', 'method'));
ALTER TABLE labels ADD CONSTRAINT labels_type_name_unique UNIQUE (type, name);

-- +goose Down
ALTER TABLE labels DROP CONSTRAINT IF EXISTS labels_type_name_unique;
ALTER TABLE labels DROP CONSTRAINT IF EXISTS labels_type_check;
ALTER TABLE labels ALTER COLUMN type DROP NOT NULL;
ALTER TABLE labels ADD COLUMN color VARCHAR;
ALTER TABLE labels DROP COLUMN type;
-- NB: legacy/junk labels deleted by Up cannot be recovered.
