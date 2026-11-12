package account

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/omomi-moti/Karaoke_support/server/internal/httpapi"
)

// newFlow は、本物の DB とルーターで API を呼ぶ関数と、サインインしてトークンを返す関数を返す。
// Apple の検証は appleUserID を返す偽物、Apple の取り消しは revoker にする。
func newFlow(t *testing.T, db *pgxpool.Pool, appleUserID string, revoker AppleRevoker) (
	call func(method, path, token, body string) *httptest.ResponseRecorder,
	signIn func() string,
) {
	t.Helper()
	svc := &Service{apple: fakeApple{sub: appleUserID}, revoker: revoker, store: NewStore(db), now: time.Now}
	h := NewHandler(svc)
	router := httpapi.NewRouter(db, svc, httpapi.Handlers{
		SignInWithApple: http.HandlerFunc(h.SignInWithApple),
		SignOut:         http.HandlerFunc(h.SignOut),
		Me:              http.HandlerFunc(h.Me),
		DeleteMe:        http.HandlerFunc(h.DeleteMe),
	})
	call = func(method, path, token, body string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(method, path, strings.NewReader(body))
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)
		return rec
	}
	signIn = func() string {
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
	return call, signIn
}

// TestSignOutFlow は、本物の DB とルーターで、ログアウトしたトークンが使えなくなることを確かめる。
// Apple の検証だけを偽物にする。
func TestSignOutFlow(t *testing.T) {
	db := testDB(t)
	appleUserID := "test-" + rand.Text()
	t.Cleanup(func() {
		db.Exec(context.Background(), `DELETE FROM users WHERE apple_user_id = $1`, appleUserID)
	})

	call, signIn := newFlow(t, db, appleUserID, &fakeRevoker{})

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

// TestDeleteAccountFlow は、本物の DB とルーターで、アカウントを消すとどの端末のトークンも使えなくなり、
// ほかの人のアカウントは残ることを確かめる。Apple の検証と取り消しだけを偽物にする。
func TestDeleteAccountFlow(t *testing.T) {
	db := testDB(t)
	appleUserID := "test-" + rand.Text()
	otherAppleUserID := "test-" + rand.Text()
	t.Cleanup(func() {
		db.Exec(context.Background(), `DELETE FROM users WHERE apple_user_id = ANY($1)`, []string{appleUserID, otherAppleUserID})
	})
	const body = `{"identityToken":"id-token","authorizationCode":"auth-code","nonce":"raw-nonce"}`

	_, signInOther := newFlow(t, db, otherAppleUserID, &fakeRevoker{})
	otherToken := signInOther()

	failing := &fakeRevoker{err: errors.New("request apple: timeout")}
	callFailing, signIn := newFlow(t, db, appleUserID, failing)
	phone := signIn()
	tablet := signIn()
	if rec := callFailing(http.MethodDelete, "/v1/me", phone, body); rec.Code != http.StatusInternalServerError {
		t.Fatalf("Apple に届かないときの削除: status = %d, want 500", rec.Code)
	}
	if rec := callFailing(http.MethodGet, "/v1/me", phone, ""); rec.Code != http.StatusOK {
		t.Fatalf("取り消しに失敗した後の /v1/me: status = %d, want 200（消えてはいけない）", rec.Code)
	}

	revoker := &fakeRevoker{}
	call, _ := newFlow(t, db, appleUserID, revoker)
	if rec := call(http.MethodDelete, "/v1/me", phone, body); rec.Code != http.StatusNoContent {
		t.Fatalf("削除: status = %d, want 204", rec.Code)
	}
	if len(revoker.gotCodes) != 1 || revoker.gotCodes[0] != "auth-code" {
		t.Fatalf("取り消しに渡したコード = %v", revoker.gotCodes)
	}
	for name, token := range map[string]string{"消した端末": phone, "ほかの端末": tablet} {
		if rec := call(http.MethodGet, "/v1/me", token, ""); rec.Code != http.StatusUnauthorized {
			t.Fatalf("%sのトークンで /v1/me: status = %d, want 401", name, rec.Code)
		}
	}
	if rec := call(http.MethodGet, "/v1/me", otherToken, ""); rec.Code != http.StatusOK {
		t.Fatalf("ほかの人のトークンで /v1/me: status = %d, want 200", rec.Code)
	}
}
