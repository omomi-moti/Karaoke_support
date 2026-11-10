package account

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/omomi-moti/Karaoke_support/server/internal/appleauth"
)

const tokenTTL = 90 * 24 * time.Hour

// ErrUnauthorized は、利用者の側の理由で受け付けられないことを表す（401 にする）。
// これ以外のエラーはサーバーの側の失敗として扱う（5xx にする）。
var ErrUnauthorized = errors.New("unauthorized")

// AppleVerifier は、Apple のトークンを確かめ、Apple のユーザー ID を返すもの。
type AppleVerifier interface {
	Verify(ctx context.Context, idToken, rawNonce string) (string, error)
}

type storage interface {
	UpsertUserByAppleID(ctx context.Context, appleUserID string) (string, error)
	CreateToken(ctx context.Context, hash []byte, userID string, expiresAt time.Time) error
	FindUserIDByTokenHash(ctx context.Context, hash []byte) (string, error)
	GetUser(ctx context.Context, userID string) (User, error)
}

// Service は、サインイン・認証・自分の情報のルールを持つ。
type Service struct {
	apple AppleVerifier
	store storage
	now   func() time.Time
}

// NewService は、apple で Apple のトークンを確かめ、store に保存する Service を返す。
func NewService(apple AppleVerifier, store *Store) *Service {
	return &Service{apple: apple, store: store, now: time.Now}
}

// SignInWithApple は、Apple のトークンを確かめ、サーバーのトークンを発行する。
// 返すトークンのそのままの値は、ここで 1 回だけ返す。DB にはハッシュだけを置く。
func (s *Service) SignInWithApple(ctx context.Context, idToken, rawNonce string) (token string, expiresAt time.Time, err error) {
	appleUserID, err := s.apple.Verify(ctx, idToken, rawNonce)
	if errors.Is(err, appleauth.ErrInvalidToken) {
		return "", time.Time{}, fmt.Errorf("%w: %w", ErrUnauthorized, err)
	}
	if err != nil {
		return "", time.Time{}, err
	}

	userID, err := s.store.UpsertUserByAppleID(ctx, appleUserID)
	if err != nil {
		return "", time.Time{}, err
	}

	raw, hash := newToken()
	expiresAt = s.now().Add(tokenTTL)
	if err := s.store.CreateToken(ctx, hash, userID, expiresAt); err != nil {
		return "", time.Time{}, err
	}
	return raw, expiresAt, nil
}

// Authenticate は、サーバーのトークンから、その持ち主のユーザー ID を返す。
func (s *Service) Authenticate(ctx context.Context, rawToken string) (string, error) {
	if !strings.HasPrefix(rawToken, tokenPrefix) {
		return "", ErrUnauthorized
	}
	userID, err := s.store.FindUserIDByTokenHash(ctx, hashToken(rawToken))
	if errors.Is(err, ErrNotFound) {
		return "", ErrUnauthorized
	}
	if err != nil {
		return "", err
	}
	return userID, nil
}

// Me は、userID のアカウントを返す。
// トークンが通った直後にアカウントが消えていたときは ErrUnauthorized を返す。
func (s *Service) Me(ctx context.Context, userID string) (User, error) {
	u, err := s.store.GetUser(ctx, userID)
	if errors.Is(err, ErrNotFound) {
		return User{}, ErrUnauthorized
	}
	return u, err
}
