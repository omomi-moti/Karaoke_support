package appleauth

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	testTeamID = "TEAM123456"
	testKeyID  = "KEY1234567"
	testCode   = "apple-authorization-code"
)

// fakeApple は、Apple の /auth/token と /auth/revoke の偽物。受け取ったフォームを覚える。
type fakeApple struct {
	mu          sync.Mutex
	tokenForms  []url.Values
	revokeForms []url.Values

	tokenStatus  int
	tokenBody    string
	revokeStatus int
}

func (f *fakeApple) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil || r.Header.Get("Content-Type") != "application/x-www-form-urlencoded" {
		w.WriteHeader(http.StatusUnsupportedMediaType)
		return
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	switch r.URL.Path {
	case "/auth/token":
		f.tokenForms = append(f.tokenForms, r.PostForm)
		w.WriteHeader(f.tokenStatus)
		w.Write([]byte(f.tokenBody))
	case "/auth/revoke":
		f.revokeForms = append(f.revokeForms, r.PostForm)
		w.WriteHeader(f.revokeStatus)
	default:
		w.WriteHeader(http.StatusNotFound)
	}
}

// forms は、受け取ったフォームを返す。
func (f *fakeApple) forms() (token, revoke []url.Values) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.tokenForms, f.revokeForms
}

func newECKey(t *testing.T) (*ecdsa.PrivateKey, []byte) {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	der, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		t.Fatal(err)
	}
	return key, pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der})
}

func newTestRevoker(t *testing.T, apple *fakeApple) (*Revoker, *ecdsa.PrivateKey) {
	t.Helper()
	key, pemKey := newECKey(t)
	r, err := NewRevoker(testAudience, testTeamID, testKeyID, pemKey)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(apple)
	t.Cleanup(server.Close)
	r.baseURL = server.URL
	r.now = func() time.Time { return testNow }
	return r, key
}

func TestRevokeWithCode(t *testing.T) {
	apple := &fakeApple{
		tokenStatus:  http.StatusOK,
		tokenBody:    `{"access_token":"apple-access","refresh_token":"apple-refresh","id_token":"x","token_type":"bearer","expires_in":3600}`,
		revokeStatus: http.StatusOK,
	}
	r, key := newTestRevoker(t, apple)

	if err := r.RevokeWithCode(context.Background(), testCode); err != nil {
		t.Fatal(err)
	}

	tokenForms, revokeForms := apple.forms()
	if len(tokenForms) != 1 || len(revokeForms) != 1 {
		t.Fatalf("token %d 回・revoke %d 回、want 1 回ずつ", len(tokenForms), len(revokeForms))
	}
	tf := tokenForms[0]
	if tf.Get("client_id") != testAudience || tf.Get("code") != testCode || tf.Get("grant_type") != "authorization_code" || tf.Has("redirect_uri") {
		t.Fatalf("token のフォーム = %v", tf)
	}
	rf := revokeForms[0]
	if rf.Get("client_id") != testAudience || rf.Get("token") != "apple-refresh" || rf.Get("token_type_hint") != "refresh_token" {
		t.Fatalf("revoke のフォーム = %v", rf)
	}

	for name, secret := range map[string]string{"token": tf.Get("client_secret"), "revoke": rf.Get("client_secret")} {
		var c jwt.RegisteredClaims
		parsed, err := jwt.ParseWithClaims(secret, &c, func(*jwt.Token) (any, error) { return &key.PublicKey, nil },
			jwt.WithValidMethods([]string{"ES256"}), jwt.WithTimeFunc(func() time.Time { return testNow }))
		if err != nil {
			t.Fatalf("%s の client_secret を確かめられない: %v", name, err)
		}
		if parsed.Header["kid"] != testKeyID {
			t.Fatalf("%s: kid = %v, want %q", name, parsed.Header["kid"], testKeyID)
		}
		if c.Issuer != testTeamID || c.Subject != testAudience || len(c.Audience) != 1 || c.Audience[0] != "https://appleid.apple.com" {
			t.Fatalf("%s: claims = %+v", name, c)
		}
		if got := c.ExpiresAt.Sub(c.IssuedAt.Time); got != 5*time.Minute {
			t.Fatalf("%s: 期限の長さ = %v, want 5m", name, got)
		}
	}
}

func TestRevokeWithCodeFallsBackToAccessToken(t *testing.T) {
	apple := &fakeApple{
		tokenStatus:  http.StatusOK,
		tokenBody:    `{"access_token":"apple-access","token_type":"bearer"}`,
		revokeStatus: http.StatusOK,
	}
	r, _ := newTestRevoker(t, apple)

	if err := r.RevokeWithCode(context.Background(), testCode); err != nil {
		t.Fatal(err)
	}
	_, revokeForms := apple.forms()
	rf := revokeForms[0]
	if rf.Get("token") != "apple-access" || rf.Get("token_type_hint") != "access_token" {
		t.Fatalf("revoke のフォーム = %v", rf)
	}
}

func TestRevokeWithCodeFailures(t *testing.T) {
	tests := []struct {
		name            string
		tokenStatus     int
		tokenBody       string
		revokeStatus    int
		wantInvalidCode bool
		wantRevokeCalls int
	}{
		{"コードの期限切れ・使い回し", 400, `{"error":"invalid_grant"}`, 0, true, 0},
		{"client_secret を受け付けない", 400, `{"error":"invalid_client"}`, 0, false, 0},
		{"Apple の側の失敗", 500, ``, 0, false, 0},
		{"トークンが返らない", 200, `{"token_type":"bearer"}`, 0, false, 0},
		{"返事が JSON でない", 200, `not json`, 0, false, 0},
		{"取り消しに失敗", 200, `{"refresh_token":"apple-refresh"}`, 400, false, 1},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			apple := &fakeApple{tokenStatus: tt.tokenStatus, tokenBody: tt.tokenBody, revokeStatus: tt.revokeStatus}
			r, _ := newTestRevoker(t, apple)

			err := r.RevokeWithCode(context.Background(), testCode)
			if err == nil {
				t.Fatal("err = nil, want an error")
			}
			if got := errors.Is(err, ErrInvalidCode); got != tt.wantInvalidCode {
				t.Fatalf("errors.Is(err, ErrInvalidCode) = %v, want %v（err = %v）", got, tt.wantInvalidCode, err)
			}
			if _, revokeForms := apple.forms(); len(revokeForms) != tt.wantRevokeCalls {
				t.Fatalf("revoke %d 回、want %d 回", len(revokeForms), tt.wantRevokeCalls)
			}
			for _, secret := range []string{testCode, "apple-refresh"} {
				if strings.Contains(err.Error(), secret) {
					t.Fatalf("エラーにコードかトークンが入っている: %v", err)
				}
			}
		})
	}
}

func TestRevokeWithCodeUnreachable(t *testing.T) {
	r, _ := newTestRevoker(t, &fakeApple{})
	server := httptest.NewServer(http.NotFoundHandler())
	r.baseURL = server.URL
	server.Close()

	err := r.RevokeWithCode(context.Background(), testCode)
	if err == nil || errors.Is(err, ErrInvalidCode) {
		t.Fatalf("err = %v, want an error that is not ErrInvalidCode", err)
	}
}

func TestNewRevokerRejectsBadKey(t *testing.T) {
	if _, err := NewRevoker(testAudience, testTeamID, testKeyID, []byte("not a key")); err == nil {
		t.Fatal("err = nil, want an error")
	}
}
