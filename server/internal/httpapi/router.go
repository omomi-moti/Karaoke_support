package httpapi

import (
	"net/http"
)

// Handlers は、機能ごとのパッケージが作る API のハンドラー。
type Handlers struct {
	SignInWithApple http.Handler
	SignOut         http.Handler
	Me              http.Handler
	DeleteMe        http.Handler
	BackupSummary   http.Handler
	GetBackup       http.Handler
	PutBackup       http.Handler
	DeleteBackup    http.Handler
}

// NewRouter は、全部の API の振り分けを持つハンドラーを返す。
// サインイン以外の /v1 の API は、auth でトークンが通ったときだけ呼ぶ。
func NewRouter(db Pinger, auth Authenticator, h Handlers) http.Handler {
	mux := http.NewServeMux()
	mux.Handle("GET /health", handleHealth(db))
	mux.Handle("POST /v1/auth/apple", h.SignInWithApple)
	mux.Handle("DELETE /v1/auth/session", RequireAuth(auth, h.SignOut))
	mux.Handle("GET /v1/me", RequireAuth(auth, h.Me))
	mux.Handle("DELETE /v1/me", RequireAuth(auth, h.DeleteMe))
	mux.Handle("GET /v1/backup/summary", RequireAuth(auth, h.BackupSummary))
	mux.Handle("GET /v1/backup", RequireAuth(auth, h.GetBackup))
	mux.Handle("PUT /v1/backup", RequireAuth(auth, h.PutBackup))
	mux.Handle("DELETE /v1/backup", RequireAuth(auth, h.DeleteBackup))
	return mux
}
