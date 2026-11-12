package account

import (
	"context"
	"crypto/rand"
	"errors"
	"os"
	"sync"
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

func TestUpsertUserByAppleIDConcurrently(t *testing.T) {
	s := NewStore(testDB(t))
	ctx := context.Background()
	appleUserID := "test-" + rand.Text()
	t.Cleanup(func() {
		s.db.Exec(context.Background(), `DELETE FROM users WHERE apple_user_id = $1`, appleUserID)
	})

	const n = 10
	ids := make([]string, n)
	errs := make([]error, n)
	var wg sync.WaitGroup
	for i := range n {
		wg.Add(1)
		go func() {
			defer wg.Done()
			ids[i], errs[i] = s.UpsertUserByAppleID(ctx, appleUserID)
		}()
	}
	wg.Wait()

	for i := range n {
		if errs[i] != nil {
			t.Fatalf("%d 本目: %v", i, errs[i])
		}
		if ids[i] != ids[0] {
			t.Fatalf("同時に呼んだら別のユーザーになった: %s, %s", ids[0], ids[i])
		}
	}
	var count int
	if err := s.db.QueryRow(ctx, `SELECT count(*) FROM users WHERE apple_user_id = $1`, appleUserID).Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("users の行が %d 行ある, want 1", count)
	}
}

// tokenRowExists は、トークンのハッシュの行が、期限にかかわらず残っているかを返す。
func tokenRowExists(t *testing.T, s *Store, hash []byte) bool {
	t.Helper()
	var exists bool
	if err := s.db.QueryRow(context.Background(), `SELECT EXISTS (SELECT 1 FROM auth_tokens WHERE token_hash = $1)`, hash).Scan(&exists); err != nil {
		t.Fatal(err)
	}
	return exists
}

func TestDeleteToken(t *testing.T) {
	s := NewStore(testDB(t))
	ctx := context.Background()
	_, userID := newTestUser(t, s)

	_, phone := newToken()
	_, tablet := newToken()
	for _, hash := range [][]byte{phone, tablet} {
		if err := s.CreateToken(ctx, hash, userID, time.Now().Add(time.Hour)); err != nil {
			t.Fatal(err)
		}
	}

	if err := s.DeleteToken(ctx, phone); err != nil {
		t.Fatal(err)
	}
	if _, err := s.FindUserIDByTokenHash(ctx, phone); !errors.Is(err, ErrNotFound) {
		t.Fatalf("消したトークン: err = %v, want ErrNotFound", err)
	}
	if got, err := s.FindUserIDByTokenHash(ctx, tablet); err != nil || got != userID {
		t.Fatalf("ほかの端末のトークン: got (%q, %v), want (%q, nil)", got, err, userID)
	}
	if err := s.DeleteToken(ctx, phone); err != nil {
		t.Fatalf("消した後にもう一度消す: %v", err)
	}
}

func TestDeleteExpiredTokens(t *testing.T) {
	s := NewStore(testDB(t))
	ctx := context.Background()
	_, userID := newTestUser(t, s)
	_, otherUserID := newTestUser(t, s)

	_, valid := newToken()
	_, expired := newToken()
	_, othersExpired := newToken()
	tokens := []struct {
		hash      []byte
		userID    string
		expiresAt time.Time
	}{
		{valid, userID, time.Now().Add(time.Hour)},
		{expired, userID, time.Now().Add(-time.Second)},
		{othersExpired, otherUserID, time.Now().Add(-time.Second)},
	}
	for _, tk := range tokens {
		if err := s.CreateToken(ctx, tk.hash, tk.userID, tk.expiresAt); err != nil {
			t.Fatal(err)
		}
	}

	if err := s.DeleteExpiredTokens(ctx, userID); err != nil {
		t.Fatal(err)
	}
	if tokenRowExists(t, s, expired) {
		t.Fatal("期限切れの行が残っている")
	}
	if !tokenRowExists(t, s, valid) {
		t.Fatal("期限内の行まで消えた")
	}
	if !tokenRowExists(t, s, othersExpired) {
		t.Fatal("ほかの人の期限切れの行まで消えた")
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

func TestAppleUserID(t *testing.T) {
	s := NewStore(testDB(t))
	ctx := context.Background()
	appleUserID, userID := newTestUser(t, s)

	if got, err := s.AppleUserID(ctx, userID); err != nil || got != appleUserID {
		t.Fatalf("got (%q, %v), want (%q, nil)", got, err, appleUserID)
	}
	if _, err := s.AppleUserID(ctx, "00000000-0000-0000-0000-000000000000"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("いないユーザー: err = %v, want ErrNotFound", err)
	}
}

func TestDeleteUser(t *testing.T) {
	s := NewStore(testDB(t))
	ctx := context.Background()
	_, userID := newTestUser(t, s)
	_, otherUserID := newTestUser(t, s)

	_, mine := newToken()
	_, others := newToken()
	if err := s.CreateToken(ctx, mine, userID, time.Now().Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	if err := s.CreateToken(ctx, others, otherUserID, time.Now().Add(time.Hour)); err != nil {
		t.Fatal(err)
	}

	if err := s.DeleteUser(ctx, userID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.GetUser(ctx, userID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("消したユーザー: err = %v, want ErrNotFound", err)
	}
	if tokenRowExists(t, s, mine) {
		t.Fatal("消したユーザーのトークンが残っている")
	}
	if _, err := s.GetUser(ctx, otherUserID); err != nil {
		t.Fatalf("ほかのユーザーまで消えた: %v", err)
	}
	if !tokenRowExists(t, s, others) {
		t.Fatal("ほかのユーザーのトークンまで消えた")
	}
	if err := s.DeleteUser(ctx, userID); err != nil {
		t.Fatalf("消した後にもう一度消す: %v", err)
	}
}
