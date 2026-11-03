package main

import (
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/omomi-moti/Karaoke_support/server/internal/httpapi"
)

func main() {
	//環境変数からPORTを取得し、指定がなければ8080を使用する
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	//httpサーバーを作る
	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           httpapi.NewRouter(),
		ReadHeaderTimeout: 5 * time.Second,
	}
	//ログの表示
	slog.Info("server starting", "port", port)
	if err := srv.ListenAndServe(); err != nil {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}
