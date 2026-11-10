-- +goose Up
CREATE TABLE auth_tokens (
    token_hash bytea       PRIMARY KEY CHECK (octet_length(token_hash) = 32),
    user_id    uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX auth_tokens_user_id_idx ON auth_tokens (user_id);

-- +goose Down
DROP TABLE auth_tokens;
