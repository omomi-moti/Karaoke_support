-- +goose Up
CREATE TABLE backups (
    user_id        uuid        PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    revision       bigint      NOT NULL CHECK (revision >= 1),
    schema_version integer     NOT NULL CHECK (schema_version >= 1),
    payload        jsonb       NOT NULL,
    track_count    integer     NOT NULL CHECK (track_count >= 0),
    session_count  integer     NOT NULL CHECK (session_count >= 0),
    updated_at     timestamptz NOT NULL DEFAULT now()
);

-- +goose Down
DROP TABLE backups;
