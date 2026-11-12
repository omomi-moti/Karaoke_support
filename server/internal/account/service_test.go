package account

import (
	"bytes"
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/omomi-moti/Karaoke_support/server/internal/appleauth"
)

type fakeApple struct {
	sub string
	err error
}

func (f fakeApple) Verify(context.Context, string, string) (string, error) {
	return f.sub, f.err
}

type savedToken struct {
	hash      []byte
	userID    string
	expiresAt time.Time
}

type fakeStore struct {
	users   map[string]User
	tokens  []savedToken
	failing error
	// cleanedUserIDs は、DeleteExpiredTokens に渡されたユーザー ID の並び。
	cleanedUserIDs []string
}

func newFakeStore() *fakeStore {
	return &fakeStore{users: map[string]User{}}
}

func (f *fakeStore) UpsertUserByAppleID(_ context.Context, appleUserID string) (string, error) {
	if f.failing != nil {
		return "", f.failing
	}
	id := "user-" + appleUserID
	f.users[id] = User{ID: id, CreatedAt: testNow}
	return id, nil
}

func (f *fakeStore) CreateToken(_ context.Context, hash []byte, userID string, expiresAt time.Time) error {
	if f.failing != nil {
		return f.failing
	}
	f.tokens = append(f.tokens, savedToken{hash: hash, userID: userID, expiresAt: expiresAt})
	return nil
}

func (f *fakeStore) DeleteToken(_ context.Context, hash []byte) error {
	if f.failing != nil {
		return f.failing
	}
	f.tokens = slices.DeleteFunc(f.tokens, func(t savedToken) bool { return bytes.Equal(t.hash, hash) })
	return nil
}

func (f *fakeStore) DeleteExpiredTokens(_ context.Context, userID string) error {
	if f.failing != nil {
		return f.failing
	}
	f.cleanedUserIDs = append(f.cleanedUserIDs, userID)
	f.tokens = slices.DeleteFunc(f.tokens, func(t savedToken) bool {
		return t.userID == userID && !t.expiresAt.After(testNow)
	})
	return nil
}

func (f *fakeStore) FindUserIDByTokenHash(_ context.Context, hash []byte) (string, error) {
	if f.failing != nil {
		return "", f.failing
	}
	for _, t := range f.tokens {
		if bytes.Equal(t.hash, hash) {
			return t.userID, nil
		}
	}
	return "", ErrNotFound
}

func (f *fakeStore) GetUser(_ context.Context, userID string) (User, error) {
	if f.failing != nil {
		return User{}, f.failing
	}
	u, ok := f.users[userID]
	if !ok {
		return User{}, ErrNotFound
	}
	return u, nil
}

var (
	testNow    = time.Date(2026, 11, 10, 12, 0, 0, 0, time.UTC)
	errDBDown  = errors.New("db down")
	ctxForTest = context.Background()
)

func newTestService(apple AppleVerifier, store *fakeStore) *Service {
	return &Service{apple: apple, store: store, now: func() time.Time { return testNow }}
}

func TestSignInWithApple(t *testing.T) {
	store := newFakeStore()
	s := newTestService(fakeApple{sub: "apple-1"}, store)

	token, expiresAt, err := s.SignInWithApple(ctxForTest, "id-token", "nonce")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(token, tokenPrefix) {
		t.Fatalf("token = %q, want prefix %q", token, tokenPrefix)
	}
	if want := testNow.Add(90 * 24 * time.Hour); !expiresAt.Equal(want) {
		t.Fatalf("expiresAt = %v, want %v", expiresAt, want)
	}

	if len(store.tokens) != 1 {
		t.Fatalf("保存したトークンの数 = %d, want 1", len(store.tokens))
	}
	saved := store.tokens[0]
	sum := sha256.Sum256([]byte(token))
	if !bytes.Equal(saved.hash, sum[:]) {
		t.Fatal("保存したのは、返したトークンの SHA-256 でなければいけない")
	}
	if saved.userID != "user-apple-1" || !saved.expiresAt.Equal(expiresAt) {
		t.Fatalf("saved = %+v", saved)
	}

	got, err := s.Authenticate(ctxForTest, token)
	if err != nil || got != "user-apple-1" {
		t.Fatalf("発行したトークンで認証: got (%q, %v), want (%q, nil)", got, err, "user-apple-1")
	}
}

func TestSignInWithAppleCleansExpiredTokens(t *testing.T) {
	store := newFakeStore()
	_, expired := newToken()
	store.tokens = append(store.tokens, savedToken{hash: expired, userID: "user-apple-1", expiresAt: testNow.Add(-time.Second)})
	s := newTestService(fakeApple{sub: "apple-1"}, store)

	if _, _, err := s.SignInWithApple(ctxForTest, "id-token", "nonce"); err != nil {
		t.Fatal(err)
	}

	if !slices.Equal(store.cleanedUserIDs, []string{"user-apple-1"}) {
		t.Fatalf("片付けたユーザー = %v, want [user-apple-1]", store.cleanedUserIDs)
	}
	if len(store.tokens) != 1 || bytes.Equal(store.tokens[0].hash, expired) {
		t.Fatalf("期限切れのトークンが残っている、または新しいトークンがない: %+v", store.tokens)
	}
}

func TestSignOut(t *testing.T) {
	store := newFakeStore()
	s := newTestService(fakeApple{sub: "apple-1"}, store)
	phone, _, err := s.SignInWithApple(ctxForTest, "id-token", "nonce")
	if err != nil {
		t.Fatal(err)
	}
	tablet, _, err := s.SignInWithApple(ctxForTest, "id-token", "nonce")
	if err != nil {
		t.Fatal(err)
	}

	if err := s.SignOut(ctxForTest, phone); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Authenticate(ctxForTest, phone); !errors.Is(err, ErrUnauthorized) {
		t.Fatalf("ログアウトしたトークン: err = %v, want ErrUnauthorized", err)
	}
	if got, err := s.Authenticate(ctxForTest, tablet); err != nil || got != "user-apple-1" {
		t.Fatalf("ほかの端末のトークン: got (%q, %v), want (%q, nil)", got, err, "user-apple-1")
	}

	store.failing = errDBDown
	if err := s.SignOut(ctxForTest, tablet); err == nil || errors.Is(err, ErrUnauthorized) {
		t.Fatalf("DB が失敗: err = %v, want an error that is not ErrUnauthorized", err)
	}
}

func TestSignInWithAppleFailures(t *testing.T) {
	invalid := fmt.Errorf("%w: nonce mismatch", appleauth.ErrInvalidToken)

	tests := []struct {
		name             string
		apple            fakeApple
		storeErr         error
		wantUnauthorized bool
	}{
		{"Apple のトークンを受け付けない", fakeApple{err: invalid}, nil, true},
		{"Apple の検証がほかの理由で失敗", fakeApple{err: errors.New("unexpected")}, nil, false},
		{"DB が失敗", fakeApple{sub: "apple-1"}, errDBDown, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := newFakeStore()
			store.failing = tt.storeErr
			s := newTestService(tt.apple, store)

			token, _, err := s.SignInWithApple(ctxForTest, "id-token", "nonce")
			if err == nil {
				t.Fatal("err = nil, want an error")
			}
			if token != "" {
				t.Fatalf("失敗したのにトークンを返した: %q", token)
			}
			if got := errors.Is(err, ErrUnauthorized); got != tt.wantUnauthorized {
				t.Fatalf("errors.Is(err, ErrUnauthorized) = %v, want %v（err = %v）", got, tt.wantUnauthorized, err)
			}
			if len(store.tokens) != 0 {
				t.Fatal("失敗したのにトークンを保存した")
			}
		})
	}
}

func TestAuthenticate(t *testing.T) {
	store := newFakeStore()
	s := newTestService(fakeApple{sub: "apple-1"}, store)
	token, _, err := s.SignInWithApple(ctxForTest, "id-token", "nonce")
	if err != nil {
		t.Fatal(err)
	}
	unknown, _ := newToken()

	tests := []struct {
		name  string
		token string
	}{
		{"空", ""},
		{"klog_ で始まらない", strings.TrimPrefix(token, tokenPrefix)},
		{"保存していない", unknown},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if _, err := s.Authenticate(ctxForTest, tt.token); !errors.Is(err, ErrUnauthorized) {
				t.Fatalf("err = %v, want ErrUnauthorized", err)
			}
		})
	}

	t.Run("DB が失敗", func(t *testing.T) {
		store.failing = errDBDown
		t.Cleanup(func() { store.failing = nil })
		_, err := s.Authenticate(ctxForTest, token)
		if err == nil || errors.Is(err, ErrUnauthorized) {
			t.Fatalf("err = %v, want an error that is not ErrUnauthorized", err)
		}
	})

	t.Run("klog_ で始まらなければ DB に行かない", func(t *testing.T) {
		store.failing = errDBDown
		t.Cleanup(func() { store.failing = nil })
		if _, err := s.Authenticate(ctxForTest, "Bearer-like-garbage"); !errors.Is(err, ErrUnauthorized) {
			t.Fatalf("err = %v, want ErrUnauthorized without touching the DB", err)
		}
	})
}

func TestMe(t *testing.T) {
	store := newFakeStore()
	s := newTestService(fakeApple{sub: "apple-1"}, store)
	userID, _ := store.UpsertUserByAppleID(ctxForTest, "apple-1")

	u, err := s.Me(ctxForTest, userID)
	if err != nil || u.ID != userID {
		t.Fatalf("got (%+v, %v), want ID %q", u, err, userID)
	}

	if _, err := s.Me(ctxForTest, "gone"); !errors.Is(err, ErrUnauthorized) {
		t.Fatalf("消えたユーザー: err = %v, want ErrUnauthorized", err)
	}

	store.failing = errDBDown
	if _, err := s.Me(ctxForTest, userID); err == nil || errors.Is(err, ErrUnauthorized) {
		t.Fatalf("DB が失敗: err = %v, want an error that is not ErrUnauthorized", err)
	}
}
