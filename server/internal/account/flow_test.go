package account

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/omomi-moti/Karaoke_support/server/internal/httpapi"
)

// TestSignOutFlow は、本物の DB とルーターで、ログアウトしたトークンが使えなくなることを確かめる。
// Apple の検証だけを偽物にする。
func TestSignOutFlow(t *testing.T) {
	db := testDB(t)
	appleUserID := "test-" + rand.Text()
	t.Cleanup(func() {
		db.Exec(context.Background(), `DELETE FROM users WHERE apple_user_id = $1`, appleUserID)
	})

	svc := &Service{apple: fakeApple{sub: appleUserID}, store: NewStore(db), now: time.Now}
	h := NewHandler(svc)
	router := httpapi.NewRouter(db, svc, httpapi.Handlers{
		SignInWithApple: http.HandlerFunc(h.SignInWithApple),
		SignOut:         http.HandlerFunc(h.SignOut),
		Me:              http.HandlerFunc(h.Me),
	})
	call := func(method, path, token, body string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(method, path, strings.NewReader(body))
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)
		return rec
	}
	signIn := func() string {
		rec := call(http.MethodPost, "/v1/auth/apple", "", `{"identityToken":"id-token","nonce":"raw-nonce"}`)
		if rec.Code != http.StatusOK {
			t.Fatalf("サインイン: status = %d", rec.Code)
		}
		var resp struct {
			Token string `json:"token"`
		}
		if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
			t.Fatal(err)
		}
		return resp.Token
	}

	phone := signIn()
	tablet := signIn()
	if rec := call(http.MethodGet, "/v1/me", phone, ""); rec.Code != http.StatusOK {
		t.Fatalf("ログアウトの前の /v1/me: status = %d, want 200", rec.Code)
	}

	if rec := call(http.MethodDelete, "/v1/auth/session", phone, ""); rec.Code != http.StatusNoContent {
		t.Fatalf("ログアウト: status = %d, want 204", rec.Code)
	}
	if rec := call(http.MethodGet, "/v1/me", phone, ""); rec.Code != http.StatusUnauthorized {
		t.Fatalf("ログアウトしたトークンで /v1/me: status = %d, want 401", rec.Code)
	}
	if rec := call(http.MethodDelete, "/v1/auth/session", phone, ""); rec.Code != http.StatusUnauthorized {
		t.Fatalf("ログアウトしたトークンでもう一度ログアウト: status = %d, want 401", rec.Code)
	}
	if rec := call(http.MethodGet, "/v1/me", tablet, ""); rec.Code != http.StatusOK {
		t.Fatalf("ほかの端末のトークンで /v1/me: status = %d, want 200", rec.Code)
	}
}
