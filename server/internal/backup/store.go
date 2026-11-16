package backup

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Contents は、置き換える中身。Payload はサーバーでは読まず、そのまま保存する。
type Contents struct {
	SchemaVersion int
	TrackCount    int
	SessionCount  int
	Payload       []byte
}

// Summary は、バックアップの版・件数・日時。中身は持たない。
type Summary struct {
	Revision      int64
	SchemaVersion int
	TrackCount    int
	SessionCount  int
	UpdatedAt     time.Time
}

// Backup は、バックアップの全部。
type Backup struct {
	Summary
	Payload []byte
}

// Store は、バックアップの SQL だけを持つ。どの SQL も userID の行だけを読み書きする。
type Store struct {
	db *pgxpool.Pool
}

// NewStore は、db を使う Store を返す。
func NewStore(db *pgxpool.Pool) *Store {
	return &Store{db: db}
}

// Create は、userID のバックアップがまだないときだけ作り、版 1 にする。
// もうあるときは何もせず ErrPreconditionFailed を返す。1 つの SQL で行うので、同時に呼ばれても 1 つだけが作る。
func (s *Store) Create(ctx context.Context, userID string, c Contents) (int64, time.Time, error) {
	const q = `
INSERT INTO backups (user_id, revision, schema_version, payload, track_count, session_count)
VALUES ($1, 1, $2, $3, $4, $5)
ON CONFLICT (user_id) DO NOTHING
RETURNING revision, updated_at`
	return s.write(ctx, "create backup", q, userID, c.SchemaVersion, c.Payload, c.TrackCount, c.SessionCount)
}

// Replace は、userID のバックアップの版が expectedRevision のときだけ置き換え、版を 1 増やす。
// 版が違う・バックアップがないときは何もせず ErrPreconditionFailed を返す。
// 1 つの SQL で比べて置き換えるので、同時に同じ版で呼ばれても 1 つだけが置き換える。
func (s *Store) Replace(ctx context.Context, userID string, expectedRevision int64, c Contents) (int64, time.Time, error) {
	const q = `
UPDATE backups
SET revision = revision + 1, schema_version = $3, payload = $4, track_count = $5, session_count = $6, updated_at = now()
WHERE user_id = $1 AND revision = $2
RETURNING revision, updated_at`
	return s.write(ctx, "replace backup", q, userID, expectedRevision, c.SchemaVersion, c.Payload, c.TrackCount, c.SessionCount)
}

func (s *Store) write(ctx context.Context, op, q string, args ...any) (int64, time.Time, error) {
	var revision int64
	var updatedAt time.Time
	err := s.db.QueryRow(ctx, q, args...).Scan(&revision, &updatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, time.Time{}, ErrPreconditionFailed
	}
	if err != nil {
		return 0, time.Time{}, fmt.Errorf("%s: %w", op, err)
	}
	return revision, updatedAt, nil
}

// Summary は、userID のバックアップの版・件数・日時を返す。ないときは ErrNotFound を返す。
func (s *Store) Summary(ctx context.Context, userID string) (Summary, error) {
	const q = `
SELECT revision, schema_version, track_count, session_count, updated_at
FROM backups WHERE user_id = $1`
	var sum Summary
	err := s.db.QueryRow(ctx, q, userID).Scan(&sum.Revision, &sum.SchemaVersion, &sum.TrackCount, &sum.SessionCount, &sum.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Summary{}, ErrNotFound
	}
	if err != nil {
		return Summary{}, fmt.Errorf("get backup summary: %w", err)
	}
	return sum, nil
}

// Get は、userID のバックアップを中身ごと返す。ないときは ErrNotFound を返す。
func (s *Store) Get(ctx context.Context, userID string) (Backup, error) {
	const q = `
SELECT revision, schema_version, track_count, session_count, updated_at, payload
FROM backups WHERE user_id = $1`
	var b Backup
	err := s.db.QueryRow(ctx, q, userID).Scan(&b.Revision, &b.SchemaVersion, &b.TrackCount, &b.SessionCount, &b.UpdatedAt, &b.Payload)
	if errors.Is(err, pgx.ErrNoRows) {
		return Backup{}, ErrNotFound
	}
	if err != nil {
		return Backup{}, fmt.Errorf("get backup: %w", err)
	}
	return b, nil
}

// Delete は、userID のバックアップを消す。ないときもエラーにしない。
func (s *Store) Delete(ctx context.Context, userID string) error {
	const q = `DELETE FROM backups WHERE user_id = $1`
	if _, err := s.db.Exec(ctx, q, userID); err != nil {
		return fmt.Errorf("delete backup: %w", err)
	}
	return nil
}
