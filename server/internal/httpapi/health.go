package httpapi

import (
	"context"
	"log/slog"
	"net/http"
	"time"
)

// Pinger は、DB につながるかを確かめられるもの。
type Pinger interface {
	Ping(ctx context.Context) error
}

// dbを受け取ってハンドラをかえす関数
func handleHealth(db Pinger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()

		w.Header().Set("Content-Type", "application/json")
		if err := db.Ping(ctx); err != nil {
			slog.Error("health check failed", "err", err)
			w.WriteHeader(http.StatusServiceUnavailable)
			w.Write([]byte(`{"status":"unavailable"}`))
			return
		}
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ok"}`))
	}
}
