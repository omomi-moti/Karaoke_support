package httpapi

import (
	"net/http"
)

// 全部の API の振り分けを持つハンドラーを返す関数。
func NewRouter() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", handleHealth)
	return mux
}
