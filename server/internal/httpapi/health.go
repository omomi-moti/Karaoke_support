package httpapi

import (
	"net/http"
)

// handleHealth は、プロセスが動いているかだけを返す。DB には触らない。
// 叩かれ続けても Neon の計算を起こさないため（ADR 0063）。
func handleHealth() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ok"}`))
	}
}
