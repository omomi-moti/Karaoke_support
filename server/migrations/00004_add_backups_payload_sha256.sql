-- +goose Up
-- 送られてきた中身のハッシュ（ADR 0061）。同じ中身の送り直しを 412 にしないために使う。前からある行は空のままで、どの送信とも一致しない。
ALTER TABLE backups
    ADD COLUMN payload_sha256 bytea CHECK (payload_sha256 IS NULL OR octet_length(payload_sha256) = 32);

-- +goose Down
ALTER TABLE backups DROP COLUMN payload_sha256;
