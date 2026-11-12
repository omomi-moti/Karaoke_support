package httpapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

type fakePinger struct {
	err error
}

func (f fakePinger) Ping(ctx context.Context) error {
	return f.err
}

func TestHealth(t *testing.T) {
	tests := []struct {
		name    string
		method  string
		pingErr error
		want    int
	}{
		{"DB につながれば 200", http.MethodGet, nil, http.StatusOK},
		{"DB につながらなければ 503", http.MethodGet, errors.New("db is down"), http.StatusServiceUnavailable},
		{"POST は 405", http.MethodPost, nil, http.StatusMethodNotAllowed},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(tt.method, "/health", nil)
			rec := httptest.NewRecorder()

			ok := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {})
			NewRouter(fakePinger{err: tt.pingErr}, &fakeAuth{}, Handlers{SignInWithApple: ok, SignOut: ok, Me: ok}).ServeHTTP(rec, req)

			if rec.Code != tt.want {
				t.Fatalf("status = %d, want %d", rec.Code, tt.want)
			}
		})
	}
}
