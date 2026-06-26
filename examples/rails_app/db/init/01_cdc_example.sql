CREATE TABLE IF NOT EXISTS users (
  id bigserial PRIMARY KEY,
  email text NOT NULL,
  name text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE users REPLICA IDENTITY DEFAULT;

CREATE PUBLICATION cdc_publication FOR TABLE users;

INSERT INTO users (email, name)
VALUES ('ada@example.test', 'Ada Lovelace')
ON CONFLICT DO NOTHING;
