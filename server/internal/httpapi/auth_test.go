package httpapi

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

type fakeAuth struct {
	userID string
	err    error
	got    string
}

func (f *fakeAuth) Authenticate(_ context.Context, rawToken string) (string, error) {
	f.got = rawToken
	return f.userID, f.err
}

func TestRequireAuth(t *testing.T) {
	tests := []struct {
		name       string
		header     string
		authErr    error
		wantStatus int
		wantBody   string
	}{
		{"トークンが通る", "Bearer klog_abc", nil, http.StatusOK, ""},
		{"Bearer は大文字小文字を問わない", "bearer klog_abc", nil, http.StatusOK, ""},
		{"ヘッダーがない", "", nil, http.StatusUnauthorized, `{"error":"unauthorized"}`},
		{"Bearer ではない", "Basic klog_abc", nil, http.StatusUnauthorized, `{"error":"unauthorized"}`},
		{"トークンが空", "Bearer ", nil, http.StatusUnauthorized, `{"error":"unauthorized"}`},
		{"トークンを断られる", "Bearer klog_abc", fmt.Errorf("%w: expired", ErrUnauthorized), http.StatusUnauthorized, `{"error":"unauthorized"}`},
		{"DB が失敗", "Bearer klog_abc", errors.New("db down"), http.StatusInternalServerError, `{"error":"internal"}`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			auth := &fakeAuth{userID: "user-1", err: tt.authErr}
			var gotUserID string
			next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				gotUserID, _ = UserID(r.Context())
				w.WriteHeader(http.StatusOK)
			})

			req := httptest.NewRequest(http.MethodGet, "/v1/me", nil)
			if tt.header != "" {
				req.Header.Set("Authorization", tt.header)
			}
			rec := httptest.NewRecorder()
			RequireAuth(auth, next).ServeHTTP(rec, req)

			if rec.Code != tt.wantStatus {
				t.Fatalf("status = %d, want %d", rec.Code, tt.wantStatus)
			}
			if tt.wantStatus == http.StatusOK {
				if gotUserID != "user-1" || auth.got != "klog_abc" {
					t.Fatalf("userID = %q, token = %q", gotUserID, auth.got)
				}
				return
			}
			if gotUserID != "" {
				t.Fatal("通らなかったのに next を呼んだ")
			}
			if got := rec.Body.String(); got != tt.wantBody+"\n" {
				t.Fatalf("body = %q, want %q", got, tt.wantBody)
			}
			if tt.wantStatus == http.StatusUnauthorized && rec.Header().Get("WWW-Authenticate") != "Bearer" {
				t.Fatal("401 に WWW-Authenticate: Bearer がない")
			}
		})
	}
}

func TestRouterAuth(t *testing.T) {
	ok := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) })
	router := NewRouter(fakePinger{}, &fakeAuth{err: ErrUnauthorized}, Handlers{SignInWithApple: ok, SignOut: ok, Me: ok})

	tests := []struct {
		method, path string
		want         int
	}{
		{http.MethodPost, "/v1/auth/apple", http.StatusOK},
		{http.MethodDelete, "/v1/auth/session", http.StatusUnauthorized},
		{http.MethodGet, "/v1/me", http.StatusUnauthorized},
	}
	for _, tt := range tests {
		t.Run(tt.method+" "+tt.path, func(t *testing.T) {
			rec := httptest.NewRecorder()
			router.ServeHTTP(rec, httptest.NewRequest(tt.method, tt.path, nil))
			if rec.Code != tt.want {
				t.Fatalf("status = %d, want %d", rec.Code, tt.want)
			}
		})
	}
}
