package httpapi

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"strings"
)

// ErrUnauthorized は、利用者の側の理由で受け付けられないことを表す（401 にする）。
var ErrUnauthorized = errors.New("unauthorized")

// Authenticator は、サーバーのトークンから、その持ち主のユーザー ID を返すもの。
// 利用者の側の理由で断るときは ErrUnauthorized を包んだエラーを返す。
type Authenticator interface {
	Authenticate(ctx context.Context, rawToken string) (string, error)
}

type userIDKey struct{}

// RequireAuth は、Authorization: Bearer のトークンが通ったときだけ next を呼ぶ。
// 通ったユーザーの ID は UserID で読める。
func RequireAuth(auth Authenticator, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token, ok := bearerToken(r)
		if !ok {
			writeUnauthorized(w)
			return
		}
		userID, err := auth.Authenticate(r.Context(), token)
		if errors.Is(err, ErrUnauthorized) {
			writeUnauthorized(w)
			return
		}
		if err != nil {
			slog.Error("authenticate", "err", err)
			WriteError(w, http.StatusInternalServerError)
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), userIDKey{}, userID)))
	})
}

// UserID は、RequireAuth が通したユーザーの ID を返す。
func UserID(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(userIDKey{}).(string)
	return id, ok
}

func bearerToken(r *http.Request) (string, bool) {
	scheme, token, ok := strings.Cut(r.Header.Get("Authorization"), " ")
	if !ok || !strings.EqualFold(scheme, "Bearer") || token == "" {
		return "", false
	}
	return token, true
}

func writeUnauthorized(w http.ResponseWriter) {
	w.Header().Set("WWW-Authenticate", "Bearer")
	WriteError(w, http.StatusUnauthorized)
}
