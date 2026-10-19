ALTER TABLE users ADD COLUMN email_verified boolean NOT NULL DEFAULT false;
CREATE TABLE email_tokens (
  token_hash text PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES users(id),
  expires_at timestamptz NOT NULL
);
