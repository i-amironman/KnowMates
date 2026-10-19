INSERT INTO skills (id, slug, name) VALUES
  ('11111111-1111-4111-8111-111111111101', 'web-development', 'Web Development'),
  ('11111111-1111-4111-8111-111111111102', 'mobile-development', 'Mobile Development'),
  ('11111111-1111-4111-8111-111111111103', 'ui-design', 'UI Design'),
  ('11111111-1111-4111-8111-111111111104', 'spanish', 'Spanish'),
  ('11111111-1111-4111-8111-111111111105', 'english-conversation', 'English Conversation'),
  ('11111111-1111-4111-8111-111111111106', 'interview-prep', 'Interview Prep'),
  ('11111111-1111-4111-8111-111111111107', 'running', 'Running')
ON CONFLICT (slug) DO NOTHING;
