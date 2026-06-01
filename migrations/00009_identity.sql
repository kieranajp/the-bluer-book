-- +goose Up
-- Identity and tenancy tables. These are the resolution layer that runs
-- BEFORE a home context is established, so they intentionally sit
-- outside the per-home RLS that 00010 enables on the tenant tables.

CREATE TABLE users (
    uuid          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subject       TEXT NOT NULL UNIQUE,         -- Kratos identity id (the X-User value)
    email         TEXT,
    display_name  TEXT,
    created_at    TIMESTAMP NOT NULL DEFAULT now(),
    updated_at    TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE homes (
    uuid        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT now(),
    updated_at  TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TYPE home_role AS ENUM ('owner', 'member');

CREATE TABLE home_members (
    home_id     UUID NOT NULL REFERENCES homes(uuid) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(uuid) ON DELETE CASCADE,
    role        home_role NOT NULL DEFAULT 'member',
    created_at  TIMESTAMP NOT NULL DEFAULT now(),
    PRIMARY KEY (home_id, user_id)
);
CREATE INDEX idx_home_members_user ON home_members(user_id);

CREATE TABLE invitations (
    uuid        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    home_id     UUID NOT NULL REFERENCES homes(uuid) ON DELETE CASCADE,
    email       TEXT NOT NULL,
    token       TEXT NOT NULL UNIQUE,
    role        home_role NOT NULL DEFAULT 'member',
    invited_by  UUID REFERENCES users(uuid) ON DELETE SET NULL,
    accepted_at TIMESTAMP NULL,
    expires_at  TIMESTAMP NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX idx_invitations_home ON invitations(home_id);

-- +goose Down
DROP TABLE IF EXISTS invitations;
DROP TABLE IF EXISTS home_members;
DROP TYPE IF EXISTS home_role;
DROP TABLE IF EXISTS homes;
DROP TABLE IF EXISTS users;
