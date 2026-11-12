package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/omomi-moti/Karaoke_support/server/internal/account"
	"github.com/omomi-moti/Karaoke_support/server/internal/appleauth"
	"github.com/omomi-moti/Karaoke_support/server/internal/httpapi"
)

func main() {
	if err := run(); err != nil {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}

func run() error {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		return errors.New("DATABASE_URL is not set")
	}

	appleBundleID := os.Getenv("APPLE_BUNDLE_ID")
	if appleBundleID == "" {
		return errors.New("APPLE_BUNDLE_ID is not set")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return fmt.Errorf("create db pool: %w", err)
	}
	defer pool.Close()

	appleKeys, err := appleauth.NewAppleKeys(ctx)
	if err != nil {
		return fmt.Errorf("create apple keys: %w", err)
	}
	accounts := account.NewService(appleauth.NewVerifier(appleKeys, appleBundleID), account.NewStore(pool))
	accountHandler := account.NewHandler(accounts)

	srv := &http.Server{
		Addr: ":" + port,
		Handler: httpapi.NewRouter(pool, accounts, httpapi.Handlers{
			SignInWithApple: http.HandlerFunc(accountHandler.SignInWithApple),
			SignOut:         http.HandlerFunc(accountHandler.SignOut),
			Me:              http.HandlerFunc(accountHandler.Me),
		}),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      20 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	slog.Info("server starting", "port", port)
	return srv.ListenAndServe()
}
