package account

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ErrNotFound は、探した行がないことを表す。
var ErrNotFound = errors.New("not found")

// User は、サーバーのアカウント。Apple の ID は外に出さない。
type User struct {
	ID        string
	CreatedAt time.Time
}

// Store は、アカウントとトークンの SQL だけを持つ。
type Store struct {
	db *pgxpool.Pool
}

// NewStore は、db を使う Store を返す。
func NewStore(db *pgxpool.Pool) *Store {
	return &Store{db: db}
}

// UpsertUserByAppleID は、Apple のユーザー ID でユーザーを探し、なければ作って、その ID を返す。
// 1 つの SQL で行うので、同時に呼ばれても 1 人のままになる。
func (s *Store) UpsertUserByAppleID(ctx context.Context, appleUserID string) (string, error) {
	const q = `
INSERT INTO users (apple_user_id) VALUES ($1)
ON CONFLICT (apple_user_id) DO UPDATE SET apple_user_id = EXCLUDED.apple_user_id
RETURNING id::text`
	var id string
	if err := s.db.QueryRow(ctx, q, appleUserID).Scan(&id); err != nil {
		return "", fmt.Errorf("upsert user: %w", err)
	}
	return id, nil
}

// CreateToken は、トークンのハッシュを userID のものとして保存する。
func (s *Store) CreateToken(ctx context.Context, hash []byte, userID string, expiresAt time.Time) error {
	const q = `INSERT INTO auth_tokens (token_hash, user_id, expires_at) VALUES ($1, $2, $3)`
	if _, err := s.db.Exec(ctx, q, hash, userID, expiresAt); err != nil {
		return fmt.Errorf("create token: %w", err)
	}
	return nil
}

// DeleteToken は、トークンのハッシュの行だけを消す。ほかの端末のトークンは残す。
// 行がなくてもエラーにしない（ログアウトを何度呼んでも同じ結果にする）。
func (s *Store) DeleteToken(ctx context.Context, hash []byte) error {
	const q = `DELETE FROM auth_tokens WHERE token_hash = $1`
	if _, err := s.db.Exec(ctx, q, hash); err != nil {
		return fmt.Errorf("delete token: %w", err)
	}
	return nil
}

// DeleteExpiredTokens は、userID の期限の切れたトークンの行を消す。
func (s *Store) DeleteExpiredTokens(ctx context.Context, userID string) error {
	const q = `DELETE FROM auth_tokens WHERE user_id = $1 AND expires_at <= now()`
	if _, err := s.db.Exec(ctx, q, userID); err != nil {
		return fmt.Errorf("delete expired tokens: %w", err)
	}
	return nil
}

// FindUserIDByTokenHash は、期限の切れていないトークンのハッシュから、ユーザー ID を返す。
// 見つからないときは ErrNotFound を返す。
func (s *Store) FindUserIDByTokenHash(ctx context.Context, hash []byte) (string, error) {
	const q = `SELECT user_id::text FROM auth_tokens WHERE token_hash = $1 AND expires_at > now()`
	var id string
	err := s.db.QueryRow(ctx, q, hash).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("find token: %w", err)
	}
	return id, nil
}

// GetUser は、userID のアカウントを返す。見つからないときは ErrNotFound を返す。
func (s *Store) GetUser(ctx context.Context, userID string) (User, error) {
	const q = `SELECT id::text, created_at FROM users WHERE id = $1`
	var u User
	err := s.db.QueryRow(ctx, q, userID).Scan(&u.ID, &u.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return User{}, ErrNotFound
	}
	if err != nil {
		return User{}, fmt.Errorf("get user: %w", err)
	}
	return u, nil
}

// AppleUserID は、userID のアカウントの Apple のユーザー ID を返す。見つからないときは ErrNotFound を返す。
func (s *Store) AppleUserID(ctx context.Context, userID string) (string, error) {
	const q = `SELECT apple_user_id FROM users WHERE id = $1`
	var appleUserID string
	err := s.db.QueryRow(ctx, q, userID).Scan(&appleUserID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("get apple user id: %w", err)
	}
	return appleUserID, nil
}

// DeleteUser は、userID のアカウントを消す。トークンなど、その人の行は ON DELETE CASCADE で一緒に消える。
// 行がなくてもエラーにしない。
func (s *Store) DeleteUser(ctx context.Context, userID string) error {
	const q = `DELETE FROM users WHERE id = $1`
	if _, err := s.db.Exec(ctx, q, userID); err != nil {
		return fmt.Errorf("delete user: %w", err)
	}
	return nil
}
