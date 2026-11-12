package account

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/omomi-moti/Karaoke_support/server/internal/appleauth"
	"github.com/omomi-moti/Karaoke_support/server/internal/httpapi"
)

const tokenTTL = 90 * 24 * time.Hour

// ErrUnauthorized は、利用者の側の理由で受け付けられないことを表す（401 にする）。
// これ以外のエラーはサーバーの側の失敗として扱う（5xx にする）。
// httpapi のミドルウェアが見分けられるように、httpapi.ErrUnauthorized と同じ値にする。
var ErrUnauthorized = httpapi.ErrUnauthorized

// ErrInvalidAppleCredential は、アカウントの削除で、Apple のトークンか認可コードを受け付けられないことを表す（400 にする）。
// サーバーのトークンは通っているので、ErrUnauthorized とは分ける（ADR 0057）。
var ErrInvalidAppleCredential = errors.New("invalid apple credential")

// ErrAppleAccountMismatch は、アカウントの削除で、もう一度サインインした Apple ID が今のアカウントのものと違うことを表す（403 にする）。
var ErrAppleAccountMismatch = errors.New("apple account does not match")

// AppleVerifier は、Apple のトークンを確かめ、Apple のユーザー ID を返すもの。
type AppleVerifier interface {
	Verify(ctx context.Context, idToken, rawNonce string) (string, error)
}

// AppleRevoker は、認可コードで Apple のトークンを取り消すもの。
type AppleRevoker interface {
	RevokeWithCode(ctx context.Context, code string) error
}

type storage interface {
	UpsertUserByAppleID(ctx context.Context, appleUserID string) (string, error)
	CreateToken(ctx context.Context, hash []byte, userID string, expiresAt time.Time) error
	DeleteToken(ctx context.Context, hash []byte) error
	DeleteExpiredTokens(ctx context.Context, userID string) error
	FindUserIDByTokenHash(ctx context.Context, hash []byte) (string, error)
	GetUser(ctx context.Context, userID string) (User, error)
	AppleUserID(ctx context.Context, userID string) (string, error)
	DeleteUser(ctx context.Context, userID string) error
}

// Service は、サインイン・認証・自分の情報・アカウントの削除のルールを持つ。
type Service struct {
	apple   AppleVerifier
	revoker AppleRevoker
	store   storage
	now     func() time.Time
}

// NewService は、apple で Apple のトークンを確かめ、revoker で取り消し、store に保存する Service を返す。
func NewService(apple AppleVerifier, revoker AppleRevoker, store *Store) *Service {
	return &Service{apple: apple, revoker: revoker, store: store, now: time.Now}
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
	if err := s.store.DeleteExpiredTokens(ctx, userID); err != nil {
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

// SignOut は、rawToken の行だけを消し、そのトークンを使えなくする。ほかの端末のトークンは残す。
// httpapi.RequireAuth を通った後に呼ぶ。
func (s *Service) SignOut(ctx context.Context, rawToken string) error {
	return s.store.DeleteToken(ctx, hashToken(rawToken))
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

// DeleteAccount は、もう一度サインインした Apple ID が userID のものかを確かめ、
// Apple のトークンを取り消せたときだけ、アカウントを消す（ADR 0057）。
// Apple の側で失敗したときは、アカウントを消さずにエラーを返す。
func (s *Service) DeleteAccount(ctx context.Context, userID, idToken, rawNonce, code string) error {
	appleUserID, err := s.apple.Verify(ctx, idToken, rawNonce)
	if errors.Is(err, appleauth.ErrInvalidToken) {
		return fmt.Errorf("%w: %w", ErrInvalidAppleCredential, err)
	}
	if err != nil {
		return err
	}

	owner, err := s.store.AppleUserID(ctx, userID)
	if errors.Is(err, ErrNotFound) {
		return ErrUnauthorized
	}
	if err != nil {
		return err
	}
	if owner != appleUserID {
		return ErrAppleAccountMismatch
	}

	if err := s.revoker.RevokeWithCode(ctx, code); err != nil {
		if errors.Is(err, appleauth.ErrInvalidCode) {
			return fmt.Errorf("%w: %w", ErrInvalidAppleCredential, err)
		}
		return err
	}
	return s.store.DeleteUser(ctx, userID)
}
