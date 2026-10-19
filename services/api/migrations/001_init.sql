-- migrations/001_init.sql
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
  id            uuid PRIMARY KEY,
  email         citext NOT NULL UNIQUE,
  password_hash text NOT NULL,
  display_name  text NOT NULL DEFAULT '',
  bio           text NOT NULL DEFAULT '',
  avatar_path   text NOT NULL DEFAULT '',
  birth_date    date NOT NULL,
  timezone      text NOT NULL,
  languages     text[] NOT NULL DEFAULT '{}',
  profile_ready boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE skills (
  id    uuid PRIMARY KEY,
  slug  text NOT NULL UNIQUE,
  name  text NOT NULL
);

CREATE TABLE user_skills (
  user_id      uuid NOT NULL REFERENCES users(id),
  skill_id     uuid NOT NULL REFERENCES skills(id),
  role         text NOT NULL CHECK (role IN ('teach', 'learn')),
  proficiency  smallint NOT NULL CHECK (proficiency BETWEEN 1 AND 5),
  PRIMARY KEY (user_id, skill_id, role)
);

CREATE TABLE availability (
  id          uuid PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES users(id),
  weekday     smallint NOT NULL CHECK (weekday BETWEEN 0 AND 6), -- 0 Monday
  start_min   smallint NOT NULL CHECK (start_min BETWEEN 0 AND 1439),
  end_min     smallint NOT NULL CHECK (end_min BETWEEN 1 AND 1440),
  CHECK (end_min > start_min)
);

CREATE TABLE refresh_tokens (
  id         uuid PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES users(id),
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz
);

CREATE TABLE swap_requests (
  id          uuid PRIMARY KEY,
  learner_id  uuid NOT NULL REFERENCES users(id),
  teacher_id  uuid NOT NULL REFERENCES users(id),
  skill_id    uuid NOT NULL REFERENCES skills(id),
  goal        text NOT NULL CHECK (char_length(goal) BETWEEN 8 AND 280),
  status      text NOT NULL CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  CHECK (learner_id <> teacher_id)
);

CREATE TABLE sessions (
  id          uuid PRIMARY KEY,
  request_id  uuid NOT NULL UNIQUE REFERENCES swap_requests(id),
  learner_id  uuid NOT NULL REFERENCES users(id),
  teacher_id  uuid NOT NULL REFERENCES users(id),
  skill_id    uuid NOT NULL REFERENCES skills(id),
  starts_at   timestamptz NOT NULL,
  ends_at     timestamptz NOT NULL,
  meeting_url text,
  status      text NOT NULL CHECK (status IN ('scheduled', 'completed', 'cancelled', 'disputed')),
  learner_done boolean NOT NULL DEFAULT false,
  teacher_done boolean NOT NULL DEFAULT false,
  CHECK (ends_at > starts_at)
);

CREATE TABLE session_messages (
  id         uuid PRIMARY KEY,
  session_id uuid NOT NULL REFERENCES sessions(id),
  sender_id  uuid NOT NULL REFERENCES users(id),
  body       text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 500),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE credit_ledger (
  id         uuid PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES users(id),
  session_id uuid REFERENCES sessions(id),
  delta      integer NOT NULL CHECK (delta <> 0),
  reason     text NOT NULL CHECK (reason IN (
               'starter_grant', 'session_hold', 'session_release', 'teach_completed'
             )),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, user_id, reason)
);

CREATE TABLE reviews (
  id          uuid PRIMARY KEY,
  session_id  uuid NOT NULL REFERENCES sessions(id),
  reviewer_id uuid NOT NULL REFERENCES users(id),
  rating      smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  body        text NOT NULL DEFAULT '',
  UNIQUE (session_id, reviewer_id)
);

CREATE TABLE blocks (
  blocker_id uuid NOT NULL REFERENCES users(id),
  blocked_id uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

CREATE TABLE reports (
  id             uuid PRIMARY KEY,
  reporter_id    uuid NOT NULL REFERENCES users(id),
  target_user_id uuid NOT NULL REFERENCES users(id),
  session_id     uuid REFERENCES sessions(id),
  reason         text NOT NULL CHECK (reason IN ('harassment', 'spam', 'safety', 'other')),
  details        text NOT NULL DEFAULT '',
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX user_skills_skill_role ON user_skills (skill_id, role);
CREATE INDEX swap_requests_teacher_status ON swap_requests (teacher_id, status);
CREATE INDEX swap_requests_learner_status ON swap_requests (learner_id, status);
CREATE INDEX sessions_learner ON sessions (learner_id, starts_at);
CREATE INDEX sessions_teacher ON sessions (teacher_id, starts_at);
CREATE INDEX session_messages_session ON session_messages (session_id, created_at);
CREATE INDEX credit_ledger_user ON credit_ledger (user_id);
CREATE UNIQUE INDEX one_starter_grant ON credit_ledger (user_id) WHERE reason = 'starter_grant';
