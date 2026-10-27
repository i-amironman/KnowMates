ALTER TABLE users
  ADD COLUMN IF NOT EXISTS gender text NOT NULL DEFAULT '' CHECK (gender IN ('', 'male', 'female'));

CREATE TABLE IF NOT EXISTS default_avatars (
  id           uuid PRIMARY KEY,
  gender       text NOT NULL CHECK (gender IN ('male', 'female')),
  avatar_path  text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS default_avatars_gender ON default_avatars (gender);
