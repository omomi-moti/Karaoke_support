package account

import (
	"context"
	"crypto/rand"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// testDB は、手元の Postgres につないだ pool を返す。
// TEST_DATABASE_URL がない・localhost 以外を指す・つながらないときは、テストを飛ばす。
func testDB(t *testing.T) *pgxpool.Pool {
	t.Helper()
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL is not set")
	}
	cfg, err := pgxpool.ParseConfig(url)
	if err != nil {
		t.Fatalf("parse TEST_DATABASE_URL: %v", err)
	}
	switch cfg.ConnConfig.Host {
	case "localhost", "127.0.0.1", "::1":
	default:
		t.Skip("TEST_DATABASE_URL does not point to localhost")
	}

	ctx := context.Background()
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	t.Cleanup(pool.Close)
	if err := pool.Ping(ctx); err != nil {
		t.Skipf("cannot reach the local Postgres: %v", err)
	}
	return pool
}

// newTestUser は、テスト用の Apple のユーザー ID でユーザーを作り、テストの後に消す。
func newTestUser(t *testing.T, s *Store) (appleUserID, userID string) {
	t.Helper()
	ctx := context.Background()
	appleUserID = "test-" + rand.Text()
	userID, err := s.UpsertUserByAppleID(ctx, appleUserID)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		s.db.Exec(context.Background(), `DELETE FROM users WHERE apple_user_id = $1`, appleUserID)
	})
	return appleUserID, userID
}

func TestUpsertUserByAppleID(t *testing.T) {
	s := NewStore(testDB(t))
	ctx := context.Background()

	appleUserID, first := newTestUser(t, s)

	second, err := s.UpsertUserByAppleID(ctx, appleUserID)
	if err != nil {
		t.Fatal(err)
	}
	if second != first {
		t.Fatalf("同じ Apple の ID で 2 回呼んだら別のユーザーになった: %s, %s", first, second)
	}

	_, other := newTestUser(t, s)
	if other == first {
		t.Fatal("違う Apple の ID で同じユーザーになった")
	}
}

func TestTokens(t *testing.T) {
	s := NewStore(testDB(t))
	ctx := context.Background()
	_, userID := newTestUser(t, s)

	_, valid := newToken()
	if err := s.CreateToken(ctx, valid, userID, time.Now().Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	_, expired := newToken()
	if err := s.CreateToken(ctx, expired, userID, time.Now().Add(-time.Second)); err != nil {
		t.Fatal(err)
	}
	_, unknown := newToken()

	got, err := s.FindUserIDByTokenHash(ctx, valid)
	if err != nil || got != userID {
		t.Fatalf("有効なトークン: got (%q, %v), want (%q, nil)", got, err, userID)
	}
	if _, err := s.FindUserIDByTokenHash(ctx, expired); !errors.Is(err, ErrNotFound) {
		t.Fatalf("期限切れのトークン: err = %v, want ErrNotFound", err)
	}
	if _, err := s.FindUserIDByTokenHash(ctx, unknown); !errors.Is(err, ErrNotFound) {
		t.Fatalf("保存していないトークン: err = %v, want ErrNotFound", err)
	}
}

func TestGetUser(t *testing.T) {
	s := NewStore(testDB(t))
	ctx := context.Background()
	_, userID := newTestUser(t, s)

	u, err := s.GetUser(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if u.ID != userID || u.CreatedAt.IsZero() {
		t.Fatalf("u = %+v, want ID %q and a creation time", u, userID)
	}

	if _, err := s.GetUser(ctx, "00000000-0000-0000-0000-000000000000"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("いないユーザー: err = %v, want ErrNotFound", err)
	}
}
