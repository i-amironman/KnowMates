CREATE TABLE notifications (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id),
  kind       text NOT NULL CHECK (kind IN ('session_request', 'request_accepted', 'chat_message')),
  ref_id     uuid NOT NULL,
  title      text NOT NULL,
  body       text NOT NULL,
  read_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX notifications_user_unread ON notifications (user_id, created_at DESC)
  WHERE read_at IS NULL;

CREATE TABLE chat_threads (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id  uuid NOT NULL UNIQUE REFERENCES swap_requests(id),
  learner_id  uuid NOT NULL REFERENCES users(id),
  teacher_id  uuid NOT NULL REFERENCES users(id),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE chat_participant_keys (
  thread_id   uuid NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES users(id),
  public_key  text NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (thread_id, user_id)
);

CREATE TABLE chat_messages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id   uuid NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
  sender_id   uuid NOT NULL REFERENCES users(id),
  ciphertext  text NOT NULL,
  nonce       text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  CHECK (char_length(ciphertext) <= 8192 AND char_length(nonce) <= 256)
);

CREATE INDEX chat_messages_thread ON chat_messages (thread_id, created_at);
