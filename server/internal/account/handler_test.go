package account

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/omomi-moti/Karaoke_support/server/internal/httpapi"
)

type fakeService struct {
	err             error
	gotIDToken      string
	gotNonce        string
	gotUserID       string
	gotSignOutToken string
	signInCalls     int
	gotDelete       []string
}

func (f *fakeService) DeleteAccount(_ context.Context, userID, idToken, rawNonce, code string) error {
	f.gotDelete = []string{userID, idToken, rawNonce, code}
	return f.err
}

func (f *fakeService) SignOut(_ context.Context, rawToken string) error {
	f.gotSignOutToken = rawToken
	return f.err
}

func (f *fakeService) SignInWithApple(_ context.Context, idToken, rawNonce string) (string, time.Time, error) {
	f.signInCalls++
	f.gotIDToken, f.gotNonce = idToken, rawNonce
	if f.err != nil {
		return "", time.Time{}, f.err
	}
	return "klog_issued", testNow.Add(tokenTTL), nil
}

func (f *fakeService) Me(_ context.Context, userID string) (User, error) {
	f.gotUserID = userID
	if f.err != nil {
		return User{}, f.err
	}
	return User{ID: userID, CreatedAt: testNow}, nil
}

func TestSignInWithAppleHandler(t *testing.T) {
	valid := `{"identityToken":"id-token","nonce":"raw-nonce"}`

	tests := []struct {
		name       string
		body       string
		svcErr     error
		wantStatus int
		wantError  string
	}{
		{"通る", valid, nil, http.StatusOK, ""},
		{"JSON ではない", `not json`, nil, http.StatusBadRequest, "invalid_request"},
		{"identityToken がない", `{"nonce":"raw-nonce"}`, nil, http.StatusBadRequest, "invalid_request"},
		{"nonce がない", `{"identityToken":"id-token"}`, nil, http.StatusBadRequest, "invalid_request"},
		{"知らない項目がある", `{"identityToken":"id-token","nonce":"raw-nonce","memo":"x"}`, nil, http.StatusBadRequest, "invalid_request"},
		{"16 KB を超える", `{"identityToken":"` + strings.Repeat("a", maxSignInBody) + `","nonce":"raw-nonce"}`, nil, http.StatusRequestEntityTooLarge, "request_too_large"},
		{"Apple のトークンを断られる", valid, fmt.Errorf("%w: nonce mismatch", ErrUnauthorized), http.StatusUnauthorized, "unauthorized"},
		{"DB が失敗", valid, errors.New("db down"), http.StatusInternalServerError, "internal"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc := &fakeService{err: tt.svcErr}
			h := &Handler{svc: svc}
			rec := httptest.NewRecorder()
			h.SignInWithApple(rec, httptest.NewRequest(http.MethodPost, "/v1/auth/apple", strings.NewReader(tt.body)))

			if rec.Code != tt.wantStatus {
				t.Fatalf("status = %d, want %d（body = %s）", rec.Code, tt.wantStatus, rec.Body)
			}
			if tt.wantStatus != http.StatusOK {
				assertError(t, rec, tt.wantError)
				if tt.wantStatus == http.StatusBadRequest || tt.wantStatus == http.StatusRequestEntityTooLarge {
					if svc.signInCalls != 0 {
						t.Fatal("本文が正しくないのに service を呼んだ")
					}
				}
				return
			}

			if svc.gotIDToken != "id-token" || svc.gotNonce != "raw-nonce" {
				t.Fatalf("service に渡した値 = (%q, %q)", svc.gotIDToken, svc.gotNonce)
			}
			if got := rec.Header().Get("Cache-Control"); got != "no-store" {
				t.Fatalf("Cache-Control = %q, want no-store", got)
			}
			var resp struct {
				Token     string    `json:"token"`
				ExpiresAt time.Time `json:"expiresAt"`
			}
			if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
				t.Fatal(err)
			}
			if resp.Token != "klog_issued" || !resp.ExpiresAt.Equal(testNow.Add(tokenTTL)) {
				t.Fatalf("resp = %+v", resp)
			}
		})
	}
}

type fakeAuthenticator struct{}

func (fakeAuthenticator) Authenticate(context.Context, string) (string, error) {
	return "user-1", nil
}

func TestMeHandler(t *testing.T) {
	tests := []struct {
		name       string
		svcErr     error
		wantStatus int
		wantError  string
	}{
		{"通る", nil, http.StatusOK, ""},
		{"アカウントが消えている", ErrUnauthorized, http.StatusUnauthorized, "unauthorized"},
		{"DB が失敗", errors.New("db down"), http.StatusInternalServerError, "internal"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc := &fakeService{err: tt.svcErr}
			h := &Handler{svc: svc}
			req := httptest.NewRequest(http.MethodGet, "/v1/me", nil)
			req.Header.Set("Authorization", "Bearer klog_abc")
			rec := httptest.NewRecorder()
			httpapi.RequireAuth(fakeAuthenticator{}, http.HandlerFunc(h.Me)).ServeHTTP(rec, req)

			if rec.Code != tt.wantStatus {
				t.Fatalf("status = %d, want %d", rec.Code, tt.wantStatus)
			}
			if tt.wantStatus != http.StatusOK {
				assertError(t, rec, tt.wantError)
				return
			}
			if svc.gotUserID != "user-1" {
				t.Fatalf("service に渡したユーザー ID = %q, want user-1", svc.gotUserID)
			}
			var resp map[string]any
			if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
				t.Fatal(err)
			}
			if len(resp) != 2 || resp["id"] != "user-1" || resp["createdAt"] == nil {
				t.Fatalf("resp = %v, want only id and createdAt", resp)
			}
		})
	}

	t.Run("RequireAuth を通っていない", func(t *testing.T) {
		h := &Handler{svc: &fakeService{}}
		rec := httptest.NewRecorder()
		h.Me(rec, httptest.NewRequest(http.MethodGet, "/v1/me", nil))
		if rec.Code != http.StatusInternalServerError {
			t.Fatalf("status = %d, want 500", rec.Code)
		}
	})
}

func TestSignOutHandler(t *testing.T) {
	tests := []struct {
		name       string
		svcErr     error
		wantStatus int
	}{
		{"通る", nil, http.StatusNoContent},
		{"DB が失敗", errors.New("db down"), http.StatusInternalServerError},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc := &fakeService{err: tt.svcErr}
			h := &Handler{svc: svc}
			req := httptest.NewRequest(http.MethodDelete, "/v1/auth/session", nil)
			req.Header.Set("Authorization", "Bearer klog_abc")
			rec := httptest.NewRecorder()
			httpapi.RequireAuth(fakeAuthenticator{}, http.HandlerFunc(h.SignOut)).ServeHTTP(rec, req)

			if rec.Code != tt.wantStatus {
				t.Fatalf("status = %d, want %d", rec.Code, tt.wantStatus)
			}
			if svc.gotSignOutToken != "klog_abc" {
				t.Fatalf("service に渡したトークン = %q, want klog_abc", svc.gotSignOutToken)
			}
			if tt.wantStatus == http.StatusNoContent {
				if rec.Body.Len() != 0 {
					t.Fatalf("204 なのに本文がある: %s", rec.Body)
				}
				return
			}
			assertError(t, rec, "internal")
		})
	}

	t.Run("RequireAuth を通っていない", func(t *testing.T) {
		svc := &fakeService{}
		h := &Handler{svc: svc}
		rec := httptest.NewRecorder()
		h.SignOut(rec, httptest.NewRequest(http.MethodDelete, "/v1/auth/session", nil))
		if rec.Code != http.StatusInternalServerError {
			t.Fatalf("status = %d, want 500", rec.Code)
		}
		if svc.gotSignOutToken != "" {
			t.Fatal("トークンがないのに service を呼んだ")
		}
	})
}

func TestDeleteMeHandler(t *testing.T) {
	valid := `{"identityToken":"id-token","authorizationCode":"auth-code","nonce":"raw-nonce"}`

	tests := []struct {
		name       string
		body       string
		svcErr     error
		wantStatus int
		wantError  string
	}{
		{"通る", valid, nil, http.StatusNoContent, ""},
		{"JSON ではない", `not json`, nil, http.StatusBadRequest, "invalid_request"},
		{"認可コードがない", `{"identityToken":"id-token","nonce":"raw-nonce"}`, nil, http.StatusBadRequest, "invalid_request"},
		{"identityToken がない", `{"authorizationCode":"auth-code","nonce":"raw-nonce"}`, nil, http.StatusBadRequest, "invalid_request"},
		{"nonce がない", `{"identityToken":"id-token","authorizationCode":"auth-code"}`, nil, http.StatusBadRequest, "invalid_request"},
		{"知らない項目がある", `{"identityToken":"id-token","authorizationCode":"auth-code","nonce":"raw-nonce","userId":"x"}`, nil, http.StatusBadRequest, "invalid_request"},
		{"16 KB を超える", `{"identityToken":"` + strings.Repeat("a", maxSignInBody) + `","authorizationCode":"auth-code","nonce":"raw-nonce"}`, nil, http.StatusRequestEntityTooLarge, "request_too_large"},
		{"Apple のトークンかコードを断られる", valid, fmt.Errorf("%w: expired", ErrInvalidAppleCredential), http.StatusBadRequest, "invalid_request"},
		{"違う Apple ID", valid, ErrAppleAccountMismatch, http.StatusForbidden, "forbidden"},
		{"アカウントがもうない", valid, ErrUnauthorized, http.StatusUnauthorized, "unauthorized"},
		{"Apple に届かない", valid, errors.New("request apple: timeout"), http.StatusInternalServerError, "internal"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc := &fakeService{err: tt.svcErr}
			h := &Handler{svc: svc}
			req := httptest.NewRequest(http.MethodDelete, "/v1/me", strings.NewReader(tt.body))
			req.Header.Set("Authorization", "Bearer klog_abc")
			rec := httptest.NewRecorder()
			httpapi.RequireAuth(fakeAuthenticator{}, http.HandlerFunc(h.DeleteMe)).ServeHTTP(rec, req)

			if rec.Code != tt.wantStatus {
				t.Fatalf("status = %d, want %d（body = %s）", rec.Code, tt.wantStatus, rec.Body)
			}
			if tt.svcErr == nil && tt.wantStatus != http.StatusNoContent {
				if svc.gotDelete != nil {
					t.Fatal("本文が正しくないのに service を呼んだ")
				}
				assertError(t, rec, tt.wantError)
				return
			}
			if want := []string{"user-1", "id-token", "raw-nonce", "auth-code"}; !slices.Equal(svc.gotDelete, want) {
				t.Fatalf("service に渡した値 = %v, want %v", svc.gotDelete, want)
			}
			if tt.wantStatus == http.StatusNoContent {
				if rec.Body.Len() != 0 {
					t.Fatalf("204 なのに本文がある: %s", rec.Body)
				}
				return
			}
			assertError(t, rec, tt.wantError)
		})
	}

	t.Run("RequireAuth を通っていない", func(t *testing.T) {
		svc := &fakeService{}
		h := &Handler{svc: svc}
		rec := httptest.NewRecorder()
		h.DeleteMe(rec, httptest.NewRequest(http.MethodDelete, "/v1/me", strings.NewReader(valid)))
		if rec.Code != http.StatusInternalServerError {
			t.Fatalf("status = %d, want 500", rec.Code)
		}
		if svc.gotDelete != nil {
			t.Fatal("ユーザー ID がないのに service を呼んだ")
		}
	})
}

func assertError(t *testing.T, rec *httptest.ResponseRecorder, want string) {
	t.Helper()
	var body map[string]string
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	if len(body) != 1 || body["error"] != want {
		t.Fatalf("body = %v, want {\"error\": %q}", body, want)
	}
}
