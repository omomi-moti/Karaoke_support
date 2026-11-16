package backup

import (
	"context"
	"crypto/rand"
	"errors"
	"os"
	"sync"
	"testing"

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

// newTestUser は、テスト用のユーザーを作り、テストの後に消す。
func newTestUser(t *testing.T, db *pgxpool.Pool) string {
	t.Helper()
	ctx := context.Background()
	appleUserID := "test-" + rand.Text()
	var userID string
	if err := db.QueryRow(ctx, `INSERT INTO users (apple_user_id) VALUES ($1) RETURNING id::text`, appleUserID).Scan(&userID); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		db.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, userID)
	})
	return userID
}

func contents(sessions int) Contents {
	return Contents{SchemaVersion: 1, TrackCount: 1, SessionCount: sessions, Payload: []byte(`{"tracks":[],"sessions":[]}`)}
}

func TestStoreCreateAndReplace(t *testing.T) {
	db := testDB(t)
	s := NewStore(db)
	ctx := context.Background()
	user := newTestUser(t, db)

	if _, err := s.Summary(ctx, user); !errors.Is(err, ErrNotFound) {
		t.Fatalf("作る前の Summary: err = %v, want ErrNotFound", err)
	}
	if _, _, err := s.Replace(ctx, user, 1, contents(1)); !errors.Is(err, ErrPreconditionFailed) {
		t.Fatalf("ないのに If-Match で置き換え: err = %v, want ErrPreconditionFailed", err)
	}

	rev, _, err := s.Create(ctx, user, contents(1))
	if err != nil || rev != 1 {
		t.Fatalf("Create: rev = %d, err = %v", rev, err)
	}
	if _, _, err := s.Create(ctx, user, contents(5)); !errors.Is(err, ErrPreconditionFailed) {
		t.Fatalf("あるのに If-None-Match で作る: err = %v, want ErrPreconditionFailed", err)
	}

	rev, _, err = s.Replace(ctx, user, 1, contents(2))
	if err != nil || rev != 2 {
		t.Fatalf("Replace: rev = %d, err = %v", rev, err)
	}
	if _, _, err := s.Replace(ctx, user, 1, contents(9)); !errors.Is(err, ErrPreconditionFailed) {
		t.Fatalf("古い版で置き換え: err = %v, want ErrPreconditionFailed", err)
	}

	got, err := s.Get(ctx, user)
	if err != nil {
		t.Fatal(err)
	}
	if got.Revision != 2 || got.SessionCount != 2 || got.SchemaVersion != 1 || got.TrackCount != 1 {
		t.Fatalf("412 の後のバックアップ = %+v（置き換わってはいけない）", got.Summary)
	}
}

// TestStoreOtherUsers は、ほかの人のバックアップに届かないことを確かめる。
func TestStoreOtherUsers(t *testing.T) {
	db := testDB(t)
	s := NewStore(db)
	ctx := context.Background()
	alice := newTestUser(t, db)
	bob := newTestUser(t, db)

	if _, _, err := s.Create(ctx, alice, contents(3)); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Summary(ctx, bob); !errors.Is(err, ErrNotFound) {
		t.Fatalf("ほかの人の Summary: err = %v, want ErrNotFound", err)
	}
	if _, _, err := s.Replace(ctx, bob, 1, contents(0)); !errors.Is(err, ErrPreconditionFailed) {
		t.Fatalf("ほかの人の版で置き換え: err = %v, want ErrPreconditionFailed", err)
	}
	if _, _, err := s.Create(ctx, bob, contents(7)); err != nil {
		t.Fatal(err)
	}
	if err := s.Delete(ctx, bob); err != nil {
		t.Fatal(err)
	}

	got, err := s.Summary(ctx, alice)
	if err != nil {
		t.Fatal(err)
	}
	if got.Revision != 1 || got.SessionCount != 3 {
		t.Fatalf("ほかの人の操作で変わった: %+v", got)
	}
}

// TestStoreReplaceConcurrently は、同じ版で同時に置き換えても、1 つだけが通ることを確かめる。
func TestStoreReplaceConcurrently(t *testing.T) {
	db := testDB(t)
	s := NewStore(db)
	ctx := context.Background()
	user := newTestUser(t, db)
	if _, _, err := s.Create(ctx, user, contents(1)); err != nil {
		t.Fatal(err)
	}

	const n = 8
	var wg sync.WaitGroup
	errs := make([]error, n)
	for i := range n {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, _, errs[i] = s.Replace(ctx, user, 1, contents(i))
		}()
	}
	wg.Wait()

	succeeded := 0
	for _, err := range errs {
		switch {
		case err == nil:
			succeeded++
		case !errors.Is(err, ErrPreconditionFailed):
			t.Fatalf("Replace: %v", err)
		}
	}
	if succeeded != 1 {
		t.Fatalf("通った数 = %d, want 1", succeeded)
	}
	if got, _ := s.Summary(ctx, user); got.Revision != 2 {
		t.Fatalf("版 = %d, want 2", got.Revision)
	}
}

func TestStoreDelete(t *testing.T) {
	db := testDB(t)
	s := NewStore(db)
	ctx := context.Background()
	user := newTestUser(t, db)

	if err := s.Delete(ctx, user); err != nil {
		t.Fatalf("ないときの Delete: %v", err)
	}
	if _, _, err := s.Create(ctx, user, contents(1)); err != nil {
		t.Fatal(err)
	}
	if err := s.Delete(ctx, user); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Summary(ctx, user); !errors.Is(err, ErrNotFound) {
		t.Fatalf("消した後の Summary: err = %v, want ErrNotFound", err)
	}
	if rev, _, err := s.Create(ctx, user, contents(1)); err != nil || rev != 1 {
		t.Fatalf("消した後にもう一度作る: rev = %d, err = %v", rev, err)
	}
}

// TestStoreDeletedWithUser は、ユーザーを消すとバックアップも消えることを確かめる（ON DELETE CASCADE）。
func TestStoreDeletedWithUser(t *testing.T) {
	db := testDB(t)
	s := NewStore(db)
	ctx := context.Background()
	user := newTestUser(t, db)
	if _, _, err := s.Create(ctx, user, contents(1)); err != nil {
		t.Fatal(err)
	}

	if _, err := db.Exec(ctx, `DELETE FROM users WHERE id = $1`, user); err != nil {
		t.Fatal(err)
	}
	var count int
	if err := db.QueryRow(ctx, `SELECT count(*) FROM backups WHERE user_id = $1`, user).Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 0 {
		t.Fatalf("ユーザーを消した後のバックアップの行 = %d, want 0", count)
	}
}
