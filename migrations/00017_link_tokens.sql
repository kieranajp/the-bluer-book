-- +goose Up
-- A link token lets another app read one home. It sits outside row-level
-- security like invitations, because the token is what decides the home.
CREATE TABLE link_tokens (
  uuid       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  home_id    UUID NOT NULL REFERENCES homes(uuid) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at TIMESTAMPTZ
);

CREATE INDEX idx_link_tokens_home ON link_tokens(home_id);

-- The server only resolves tokens. Issuing and revoking run as the owner.
REVOKE ALL ON link_tokens FROM bluer_book_app;
GRANT SELECT ON link_tokens TO bluer_book_app;

-- +goose Down
DROP TABLE IF EXISTS link_tokens;
