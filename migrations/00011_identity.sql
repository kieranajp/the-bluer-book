-- +goose Up
-- Identity and tenancy tables: who is calling, which homes exist, and who
-- belongs to which. These run before a home is known for a request, so they
-- stay outside the per-home row-level security that later migrations put on the
-- tenant tables.

CREATE TABLE users (
  uuid         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  subject      TEXT NOT NULL UNIQUE,
  email        TEXT NOT NULL DEFAULT '',
  display_name TEXT NOT NULL DEFAULT '',
  created_at   TIMESTAMP NOT NULL DEFAULT now(),
  updated_at   TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE homes (
  uuid       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name       TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TYPE home_role AS ENUM ('owner', 'member');

CREATE TABLE home_members (
  home_id    UUID NOT NULL REFERENCES homes(uuid) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(uuid) ON DELETE CASCADE,
  role       home_role NOT NULL DEFAULT 'member',
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (home_id, user_id)
);

CREATE INDEX idx_home_members_user ON home_members(user_id, created_at DESC);

CREATE TABLE invitations (
  uuid        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  home_id     UUID NOT NULL REFERENCES homes(uuid) ON DELETE CASCADE,
  email       TEXT NOT NULL,
  token       TEXT NOT NULL UNIQUE,
  role        home_role NOT NULL DEFAULT 'member',
  invited_by  UUID REFERENCES users(uuid) ON DELETE SET NULL,
  accepted_at TIMESTAMP,
  expires_at  TIMESTAMP NOT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_invitations_home ON invitations(home_id);

-- The founder home exists from here on so that the operator's first login
-- attaches to it. Every recipe already in the book is later stamped with this
-- id; provision the operator into a fresh home instead and they would see none
-- of it.
INSERT INTO homes (uuid, name) VALUES ('00000000-0000-0000-0000-000000000001', 'Founder');

-- +goose Down
DROP TABLE IF EXISTS invitations;
DROP TABLE IF EXISTS home_members;
DROP TYPE IF EXISTS home_role;
DROP TABLE IF EXISTS homes;
DROP TABLE IF EXISTS users;
