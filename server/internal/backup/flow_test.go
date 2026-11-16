package backup

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/omomi-moti/Karaoke_support/server/internal/httpapi"
)

// tokenAuth は、トークンの値をそのままユーザー ID として通す偽の認証。
type tokenAuth struct{}

func (tokenAuth) Authenticate(ctx context.Context, rawToken string) (string, error) {
	return rawToken, nil
}

// TestBackupFlow は、本物の DB とルーターで、版の番号つきの置き換えと、ほかの人の控えに届かないことを確かめる。
// 認証だけを偽物にし、トークンの値をユーザー ID として扱う。
func TestBackupFlow(t *testing.T) {
	db := testDB(t)
	alice := newTestUser(t, db)
	bob := newTestUser(t, db)

	h := NewHandler(NewService(NewStore(db)))
	ok := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {})
	router := httpapi.NewRouter(db, tokenAuth{}, httpapi.Handlers{
		SignInWithApple: ok, SignOut: ok, Me: ok, DeleteMe: ok,
		BackupSummary: http.HandlerFunc(h.Summary),
		GetBackup:     http.HandlerFunc(h.Get),
		PutBackup:     http.HandlerFunc(h.Put),
		DeleteBackup:  http.HandlerFunc(h.Delete),
	})
	call := func(method, path, user string, header map[string]string, body string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(method, path, strings.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+user)
		for k, v := range header {
			req.Header.Set(k, v)
		}
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)
		return rec
	}
	put := func(user string, header map[string]string, sessions string) *httptest.ResponseRecorder {
		body := `{"schemaVersion":1,"trackCount":1,"sessionCount":` + sessions + `,"payload":{"tracks":[],"sessions":[]}}`
		return call(http.MethodPut, "/v1/backup", user, header, body)
	}
	summary := func(user string) (int, summaryResponse) {
		rec := call(http.MethodGet, "/v1/backup/summary", user, nil, "")
		var resp summaryResponse
		if rec.Code == http.StatusOK {
			if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
				t.Fatal(err)
			}
		}
		return rec.Code, resp
	}

	if rec := put(alice, nil, "1"); rec.Code != http.StatusPreconditionRequired {
		t.Fatalf("条件なし: status = %d, want 428", rec.Code)
	}
	if code, _ := summary(alice); code != http.StatusNotFound {
		t.Fatalf("428 の後の summary: status = %d, want 404（作ってはいけない）", code)
	}

	if rec := put(alice, map[string]string{"If-None-Match": "*"}, "1"); rec.Code != http.StatusOK || rec.Header().Get("ETag") != `"1"` {
		t.Fatalf("初めて送る: status = %d, ETag = %q", rec.Code, rec.Header().Get("ETag"))
	}
	if rec := put(alice, map[string]string{"If-Match": `"1"`}, "2"); rec.Code != http.StatusOK || rec.Header().Get("ETag") != `"2"` {
		t.Fatalf("版 1 で置き換え: status = %d, ETag = %q", rec.Code, rec.Header().Get("ETag"))
	}

	// ほかの端末が版 2 にした後で、古い版 1 のまま送った端末は置き換えられない
	if rec := put(alice, map[string]string{"If-Match": `"1"`}, "9"); rec.Code != http.StatusPreconditionFailed {
		t.Fatalf("古い版で置き換え: status = %d, want 412", rec.Code)
	}
	if rec := put(alice, map[string]string{"If-None-Match": "*"}, "9"); rec.Code != http.StatusPreconditionFailed {
		t.Fatalf("あるのに If-None-Match: status = %d, want 412", rec.Code)
	}
	if code, got := summary(alice); code != http.StatusOK || got.Revision != 2 || got.SessionCount != 2 {
		t.Fatalf("412 の後の summary: status = %d, %+v（置き換わってはいけない）", code, got)
	}

	// ほかの人のトークンでは、alice の控えは見えず、変えられず、消せない
	if code, _ := summary(bob); code != http.StatusNotFound {
		t.Fatalf("bob の summary: status = %d, want 404", code)
	}
	if rec := put(bob, map[string]string{"If-Match": `"2"`}, "0"); rec.Code != http.StatusPreconditionFailed {
		t.Fatalf("bob が alice の版で置き換え: status = %d, want 412", rec.Code)
	}
	if rec := call(http.MethodDelete, "/v1/backup", bob, nil, ""); rec.Code != http.StatusNoContent {
		t.Fatalf("bob の削除: status = %d, want 204", rec.Code)
	}
	if code, got := summary(alice); code != http.StatusOK || got.Revision != 2 {
		t.Fatalf("bob の操作の後の alice の summary: status = %d, %+v", code, got)
	}

	if rec := call(http.MethodGet, "/v1/backup", alice, nil, ""); rec.Code != http.StatusOK {
		t.Fatalf("GET /v1/backup: status = %d, want 200", rec.Code)
	}
	for range 2 {
		if rec := call(http.MethodDelete, "/v1/backup", alice, nil, ""); rec.Code != http.StatusNoContent {
			t.Fatalf("削除: status = %d, want 204", rec.Code)
		}
	}
	if code, _ := summary(alice); code != http.StatusNotFound {
		t.Fatalf("消した後の summary: status = %d, want 404", code)
	}
}
