CREATE TABLE device_tokens (
  user_id    uuid NOT NULL REFERENCES users(id),
  token      text PRIMARY KEY,
  updated_at timestamptz NOT NULL DEFAULT now()
);
