package httpapi

import (
	"net/http"
)

// NewRouter は、全部の API の振り分けを持つハンドラーを返す。
func NewRouter(db Pinger) http.Handler {
	mux := http.NewServeMux()
	mux.Handle("GET /health", handleHealth(db))
	return mux
}
