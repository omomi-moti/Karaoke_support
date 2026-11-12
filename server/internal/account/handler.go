package account

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/omomi-moti/Karaoke_support/server/internal/httpapi"
)

const maxSignInBody = 16 << 10

type accountService interface {
	SignInWithApple(ctx context.Context, idToken, rawNonce string) (string, time.Time, error)
	SignOut(ctx context.Context, rawToken string) error
	Me(ctx context.Context, userID string) (User, error)
	DeleteAccount(ctx context.Context, userID, idToken, rawNonce, code string) error
}

// Handler は、アカウントの API の入出力を持つ。
type Handler struct {
	svc accountService
}

// NewHandler は、svc を呼ぶ Handler を返す。
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

type signInRequest struct {
	IdentityToken string `json:"identityToken"`
	Nonce         string `json:"nonce"`
}

type deleteMeRequest struct {
	IdentityToken     string `json:"identityToken"`
	AuthorizationCode string `json:"authorizationCode"`
	Nonce             string `json:"nonce"`
}

type signInResponse struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expiresAt"`
}

type meResponse struct {
	ID        string    `json:"id"`
	CreatedAt time.Time `json:"createdAt"`
}

// SignInWithApple は POST /v1/auth/apple。Apple のトークンと nonce を受け取り、サーバーのトークンを返す。
func (h *Handler) SignInWithApple(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxSignInBody)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()

	var req signInRequest
	if err := dec.Decode(&req); err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			httpapi.WriteError(w, http.StatusRequestEntityTooLarge)
			return
		}
		httpapi.WriteError(w, http.StatusBadRequest)
		return
	}
	if req.IdentityToken == "" || req.Nonce == "" {
		httpapi.WriteError(w, http.StatusBadRequest)
		return
	}

	token, expiresAt, err := h.svc.SignInWithApple(r.Context(), req.IdentityToken, req.Nonce)
	if errors.Is(err, ErrUnauthorized) {
		slog.Warn("apple sign-in rejected", "err", err)
		httpapi.WriteError(w, http.StatusUnauthorized)
		return
	}
	if err != nil {
		slog.Error("apple sign-in", "err", err)
		httpapi.WriteError(w, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Cache-Control", "no-store")
	httpapi.WriteJSON(w, http.StatusOK, signInResponse{Token: token, ExpiresAt: expiresAt.UTC()})
}

// SignOut は DELETE /v1/auth/session。送られたトークンを使えなくし、204 を返す。httpapi.RequireAuth の内側で呼ぶ。
func (h *Handler) SignOut(w http.ResponseWriter, r *http.Request) {
	token, ok := httpapi.BearerToken(r)
	if !ok {
		slog.Error("sign out: no bearer token")
		httpapi.WriteError(w, http.StatusInternalServerError)
		return
	}
	if err := h.svc.SignOut(r.Context(), token); err != nil {
		slog.Error("sign out", "err", err)
		httpapi.WriteError(w, http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Me は GET /v1/me。トークンの持ち主のアカウントを返す。httpapi.RequireAuth の内側で呼ぶ。
func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	userID, ok := httpapi.UserID(r.Context())
	if !ok {
		slog.Error("me: no user id in context")
		httpapi.WriteError(w, http.StatusInternalServerError)
		return
	}

	u, err := h.svc.Me(r.Context(), userID)
	if errors.Is(err, ErrUnauthorized) {
		httpapi.WriteError(w, http.StatusUnauthorized)
		return
	}
	if err != nil {
		slog.Error("me", "err", err)
		httpapi.WriteError(w, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Cache-Control", "no-store")
	httpapi.WriteJSON(w, http.StatusOK, meResponse{ID: u.ID, CreatedAt: u.CreatedAt.UTC()})
}

// DeleteMe は DELETE /v1/me。もう一度サインインした Apple のトークン・nonce・認可コードを受け取り、
// Apple のトークンを取り消してから、トークンの持ち主のアカウントを消す。httpapi.RequireAuth の内側で呼ぶ（ADR 0057）。
func (h *Handler) DeleteMe(w http.ResponseWriter, r *http.Request) {
	userID, ok := httpapi.UserID(r.Context())
	if !ok {
		slog.Error("delete me: no user id in context")
		httpapi.WriteError(w, http.StatusInternalServerError)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxSignInBody)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	var req deleteMeRequest
	if err := dec.Decode(&req); err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			httpapi.WriteError(w, http.StatusRequestEntityTooLarge)
			return
		}
		httpapi.WriteError(w, http.StatusBadRequest)
		return
	}
	if req.IdentityToken == "" || req.AuthorizationCode == "" || req.Nonce == "" {
		httpapi.WriteError(w, http.StatusBadRequest)
		return
	}

	err := h.svc.DeleteAccount(r.Context(), userID, req.IdentityToken, req.Nonce, req.AuthorizationCode)
	switch {
	case err == nil:
		w.WriteHeader(http.StatusNoContent)
	case errors.Is(err, ErrInvalidAppleCredential):
		slog.Warn("delete me: apple credential rejected", "err", err)
		httpapi.WriteError(w, http.StatusBadRequest)
	case errors.Is(err, ErrAppleAccountMismatch):
		slog.Warn("delete me: apple account does not match")
		httpapi.WriteError(w, http.StatusForbidden)
	case errors.Is(err, ErrUnauthorized):
		httpapi.WriteError(w, http.StatusUnauthorized)
	default:
		slog.Error("delete me", "err", err)
		httpapi.WriteError(w, http.StatusInternalServerError)
	}
}
