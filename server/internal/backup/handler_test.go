package backup

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/omomi-moti/Karaoke_support/server/internal/httpapi"
)

type fakeService struct {
	putErr    error
	gotUserID string
	gotCond   Condition
	gotPut    *Contents
	summary   Summary
	backup    Backup
	readErr   error
	deleteErr error
}

func (f *fakeService) Put(ctx context.Context, userID string, cond Condition, c Contents) (int64, time.Time, error) {
	f.gotUserID, f.gotCond, f.gotPut = userID, cond, &c
	if f.putErr != nil {
		return 0, time.Time{}, f.putErr
	}
	return 8, time.Date(2026, 11, 13, 1, 2, 3, 0, time.UTC), nil
}

func (f *fakeService) Summary(ctx context.Context, userID string) (Summary, error) {
	f.gotUserID = userID
	return f.summary, f.readErr
}

func (f *fakeService) Get(ctx context.Context, userID string) (Backup, error) {
	f.gotUserID = userID
	return f.backup, f.readErr
}

func (f *fakeService) Delete(ctx context.Context, userID string) error {
	f.gotUserID = userID
	return f.deleteErr
}

type fakeAuth struct{}

func (fakeAuth) Authenticate(ctx context.Context, rawToken string) (string, error) {
	return "user-" + rawToken, nil
}

// serve は、本物のルーターと認証のミドルウェアを通して svc を呼ぶ。
func serve(svc *fakeService, method, path string, header http.Header, body string) *httptest.ResponseRecorder {
	h := &Handler{svc: svc}
	ok := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {})
	router := httpapi.NewRouter(nil, fakeAuth{}, httpapi.Handlers{
		SignInWithApple: ok, SignOut: ok, Me: ok, DeleteMe: ok,
		BackupSummary: http.HandlerFunc(h.Summary),
		GetBackup:     http.HandlerFunc(h.Get),
		PutBackup:     http.HandlerFunc(h.Put),
		DeleteBackup:  http.HandlerFunc(h.Delete),
	})
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	for k, vs := range header {
		for _, v := range vs {
			req.Header.Add(k, v)
		}
	}
	req.Header.Set("Authorization", "Bearer a")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}

const validBody = `{"schemaVersion":1,"trackCount":1,"sessionCount":2,"payload":{"tracks":[{"userEnteredName":"秘密の曲"}],"sessions":[]}}`

func errorCode(t *testing.T, rec *httptest.ResponseRecorder) string {
	t.Helper()
	var body map[string]string
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("エラーの返事を読めない: %v", err)
	}
	return body["error"]
}

func TestPutCondition(t *testing.T) {
	tests := []struct {
		name     string
		header   http.Header
		want     int
		wantCode string
		wantCond *Condition
	}{
		{"条件がなければ 428", http.Header{}, http.StatusPreconditionRequired, "precondition_required", nil},
		{"If-None-Match: * は作る", http.Header{"If-None-Match": {"*"}}, http.StatusOK, "", &Condition{IfNoneMatch: true}},
		{"If-Match は版を渡す", http.Header{"If-Match": {`"7"`}}, http.StatusOK, "", &Condition{IfMatch: 7}},
		{"両方あれば 400", http.Header{"If-Match": {`"7"`}, "If-None-Match": {"*"}}, http.StatusBadRequest, "invalid_request", nil},
		{"If-Match が 2 つあれば 400", http.Header{"If-Match": {`"7"`, `"8"`}}, http.StatusBadRequest, "invalid_request", nil},
		{"If-Match の引用符がなければ 400", http.Header{"If-Match": {"7"}}, http.StatusBadRequest, "invalid_request", nil},
		{"If-Match の弱い ETag は 400", http.Header{"If-Match": {`W/"7"`}}, http.StatusBadRequest, "invalid_request", nil},
		{"If-Match: * は 400", http.Header{"If-Match": {"*"}}, http.StatusBadRequest, "invalid_request", nil},
		{"If-Match の版が 0 なら 400", http.Header{"If-Match": {`"0"`}}, http.StatusBadRequest, "invalid_request", nil},
		{"If-Match の版が数でなければ 400", http.Header{"If-Match": {`"abc"`}}, http.StatusBadRequest, "invalid_request", nil},
		{"If-None-Match が * でなければ 400", http.Header{"If-None-Match": {`"7"`}}, http.StatusBadRequest, "invalid_request", nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc := &fakeService{}
			rec := serve(svc, http.MethodPut, "/v1/backup", tt.header, validBody)
			if rec.Code != tt.want {
				t.Fatalf("status = %d, want %d", rec.Code, tt.want)
			}
			if tt.wantCond == nil {
				if svc.gotPut != nil {
					t.Fatal("条件が通らないのに置き換えを呼んだ")
				}
				if got := errorCode(t, rec); got != tt.wantCode {
					t.Fatalf("error = %q, want %q", got, tt.wantCode)
				}
				return
			}
			if svc.gotCond != *tt.wantCond {
				t.Fatalf("cond = %+v, want %+v", svc.gotCond, *tt.wantCond)
			}
		})
	}
}

func TestPutSuccess(t *testing.T) {
	svc := &fakeService{}
	rec := serve(svc, http.MethodPut, "/v1/backup", http.Header{"If-Match": {`"7"`}}, validBody)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if got := rec.Header().Get("ETag"); got != `"8"` {
		t.Fatalf("ETag = %q, want \"8\"", got)
	}
	var resp putResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatal(err)
	}
	if resp.Revision != 8 || !resp.UpdatedAt.Equal(time.Date(2026, 11, 13, 1, 2, 3, 0, time.UTC)) {
		t.Fatalf("返事 = %+v", resp)
	}
	if svc.gotUserID != "user-a" {
		t.Fatalf("userID = %q, want トークンの持ち主", svc.gotUserID)
	}
	got := svc.gotPut
	if got.SchemaVersion != 1 || got.TrackCount != 1 || got.SessionCount != 2 || !strings.Contains(string(got.Payload), "秘密の曲") {
		t.Fatalf("渡した中身 = %+v", got)
	}
}

func TestPutBody(t *testing.T) {
	tests := []struct {
		name     string
		body     string
		svcErr   error
		want     int
		wantCode string
	}{
		{"壊れた JSON は 400", `{"schemaVersion":`, nil, http.StatusBadRequest, "invalid_request"},
		{"知らない項目（memo など）は 400", `{"schemaVersion":1,"trackCount":0,"sessionCount":0,"payload":{},"memo":"x"}`, nil, http.StatusBadRequest, "invalid_request"},
		{"payload がなければ 400", `{"schemaVersion":1,"trackCount":0,"sessionCount":0}`, nil, http.StatusBadRequest, "invalid_request"},
		{"payload が null なら 400", `{"schemaVersion":1,"trackCount":0,"sessionCount":0,"payload":null}`, nil, http.StatusBadRequest, "invalid_request"},
		{"payload が配列なら 400", `{"schemaVersion":1,"trackCount":0,"sessionCount":0,"payload":[]}`, nil, http.StatusBadRequest, "invalid_request"},
		{"5MB を超えたら 413", `{"schemaVersion":1,"trackCount":0,"sessionCount":0,"payload":{"x":"` + strings.Repeat("a", maxBackupBody) + `"}}`, nil, http.StatusRequestEntityTooLarge, "request_too_large"},
		{"受け付けない中身は 400", validBody, ErrInvalidBackup, http.StatusBadRequest, "invalid_request"},
		{"版が合わなければ 412", validBody, ErrPreconditionFailed, http.StatusPreconditionFailed, "precondition_failed"},
		{"DB の失敗は 500", validBody, errors.New("db is down"), http.StatusInternalServerError, "internal"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rec := serve(&fakeService{putErr: tt.svcErr}, http.MethodPut, "/v1/backup", http.Header{"If-None-Match": {"*"}}, tt.body)
			if rec.Code != tt.want {
				t.Fatalf("status = %d, want %d", rec.Code, tt.want)
			}
			if got := errorCode(t, rec); got != tt.wantCode {
				t.Fatalf("error = %q, want %q", got, tt.wantCode)
			}
		})
	}
}

// TestPutDoesNotLogContents は、失敗したときも、記録の中身をログとエラーの返事に出さないことを確かめる（NFR-3）。
func TestPutDoesNotLogContents(t *testing.T) {
	var logs bytes.Buffer
	prev := slog.Default()
	slog.SetDefault(slog.New(slog.NewTextHandler(&logs, nil)))
	t.Cleanup(func() { slog.SetDefault(prev) })

	for _, err := range []error{ErrInvalidBackup, ErrPreconditionFailed, errors.New("db is down")} {
		rec := serve(&fakeService{putErr: err}, http.MethodPut, "/v1/backup", http.Header{"If-None-Match": {"*"}}, validBody)
		if strings.Contains(rec.Body.String(), "秘密の曲") {
			t.Fatalf("エラーの返事に曲名が出た: %s", rec.Body.String())
		}
	}
	if strings.Contains(logs.String(), "秘密の曲") {
		t.Fatalf("ログに曲名が出た: %s", logs.String())
	}
}

func TestSummary(t *testing.T) {
	updated := time.Date(2026, 11, 13, 1, 2, 3, 0, time.UTC)
	svc := &fakeService{summary: Summary{Revision: 3, SchemaVersion: 1, TrackCount: 4, SessionCount: 9, UpdatedAt: updated}}
	rec := serve(svc, http.MethodGet, "/v1/backup/summary", nil, "")
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if got := rec.Header().Get("ETag"); got != `"3"` {
		t.Fatalf("ETag = %q", got)
	}
	if got := rec.Header().Get("Cache-Control"); got != "no-store" {
		t.Fatalf("Cache-Control = %q", got)
	}
	var resp summaryResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatal(err)
	}
	want := summaryResponse{Revision: 3, SchemaVersion: 1, TrackCount: 4, SessionCount: 9, UpdatedAt: updated}
	if resp != want {
		t.Fatalf("返事 = %+v, want %+v", resp, want)
	}
}

func TestReadNotFound(t *testing.T) {
	for _, path := range []string{"/v1/backup/summary", "/v1/backup"} {
		rec := serve(&fakeService{readErr: ErrNotFound}, http.MethodGet, path, nil, "")
		if rec.Code != http.StatusNotFound {
			t.Fatalf("%s: status = %d, want 404", path, rec.Code)
		}
		if got := errorCode(t, rec); got != "not_found" {
			t.Fatalf("%s: error = %q", path, got)
		}
	}
}

func TestGet(t *testing.T) {
	svc := &fakeService{backup: Backup{
		Summary: Summary{Revision: 2, SchemaVersion: 1, TrackCount: 1, SessionCount: 1, UpdatedAt: time.Now()},
		Payload: []byte(`{"tracks":[],"sessions":[]}`),
	}}
	rec := serve(svc, http.MethodGet, "/v1/backup", nil, "")
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	var resp struct {
		Revision int64           `json:"revision"`
		Payload  json.RawMessage `json:"payload"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatal(err)
	}
	if resp.Revision != 2 || string(resp.Payload) != `{"tracks":[],"sessions":[]}` {
		t.Fatalf("返事 = %+v", resp)
	}
}

func TestDelete(t *testing.T) {
	svc := &fakeService{}
	if rec := serve(svc, http.MethodDelete, "/v1/backup", nil, ""); rec.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want 204", rec.Code)
	}
	if svc.gotUserID != "user-a" {
		t.Fatalf("userID = %q", svc.gotUserID)
	}
	if rec := serve(&fakeService{deleteErr: errors.New("db is down")}, http.MethodDelete, "/v1/backup", nil, ""); rec.Code != http.StatusInternalServerError {
		t.Fatalf("DB の失敗: status = %d, want 500", rec.Code)
	}
}
