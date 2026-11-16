package httpapi

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

// TestHealth は、/health が DB に触らずに返すことを確かめる。ルーターは DB を受け取らない（ADR 0063）。
func TestHealth(t *testing.T) {
	tests := []struct {
		name   string
		method string
		want   int
	}{
		{"GET は 200", http.MethodGet, http.StatusOK},
		{"POST は 405", http.MethodPost, http.StatusMethodNotAllowed},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(tt.method, "/health", nil)
			rec := httptest.NewRecorder()

			ok := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {})
			NewRouter(&fakeAuth{}, Handlers{SignInWithApple: ok, SignOut: ok, Me: ok, DeleteMe: ok, BackupSummary: ok, GetBackup: ok, PutBackup: ok, DeleteBackup: ok}).ServeHTTP(rec, req)

			if rec.Code != tt.want {
				t.Fatalf("status = %d, want %d", rec.Code, tt.want)
			}
			if tt.want == http.StatusOK && rec.Body.String() != `{"status":"ok"}` {
				t.Fatalf("body = %q", rec.Body.String())
			}
		})
	}
}
