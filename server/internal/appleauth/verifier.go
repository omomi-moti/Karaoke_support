// Package appleauth は、Sign in with Apple のトークンを確かめる（ADR 0054）。
package appleauth

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	issuer = "https://appleid.apple.com"
	leeway = time.Minute
	maxAge = 10 * time.Minute
)

// ErrInvalidToken は、Apple のトークンを受け付けられないことを表す。
// 理由は包んだエラーの中にだけ入れ、利用者への返事には出さない。
var ErrInvalidToken = errors.New("invalid apple identity token")

// KeySource は、トークンの署名を確かめる鍵を返すもの。
type KeySource interface {
	KeyfuncCtx(ctx context.Context) jwt.Keyfunc
}

// Verifier は、Apple のトークンが、このアプリのために今出されたものかを確かめる。
type Verifier struct {
	keys     KeySource
	audience string
	now      func() time.Time
}

// NewVerifier は、audience（アプリのバンドル ID）宛てのトークンだけを受け付ける Verifier を返す。
func NewVerifier(keys KeySource, audience string) *Verifier {
	return &Verifier{keys: keys, audience: audience, now: time.Now}
}

type claims struct {
	jwt.RegisteredClaims
	Nonce string `json:"nonce"`
}

// Verify は idToken を確かめ、Apple のユーザー ID（sub）を返す。
// rawNonce は iOS が作った元の nonce で、Apple には SHA-256 を 16 進数にしたものが渡っている。
// 受け付けられないときは ErrInvalidToken を包んだエラーを返す。
func (v *Verifier) Verify(ctx context.Context, idToken, rawNonce string) (string, error) {
	parser := jwt.NewParser(
		jwt.WithValidMethods([]string{jwt.SigningMethodRS256.Alg()}),
		jwt.WithIssuer(issuer),
		jwt.WithAudience(v.audience),
		jwt.WithExpirationRequired(),
		jwt.WithIssuedAt(),
		jwt.WithLeeway(leeway),
		jwt.WithTimeFunc(v.now),
	)

	var c claims
	if _, err := parser.ParseWithClaims(idToken, &c, v.keys.KeyfuncCtx(ctx)); err != nil {
		return "", fmt.Errorf("%w: %w", ErrInvalidToken, err)
	}
	if len(c.Audience) != 1 || c.Audience[0] != v.audience {
		return "", fmt.Errorf("%w: unexpected audience", ErrInvalidToken)
	}
	if c.IssuedAt == nil || v.now().Sub(c.IssuedAt.Time) > maxAge {
		return "", fmt.Errorf("%w: issued too long ago", ErrInvalidToken)
	}
	if rawNonce == "" || subtle.ConstantTimeCompare([]byte(c.Nonce), []byte(hashNonce(rawNonce))) != 1 {
		return "", fmt.Errorf("%w: nonce mismatch", ErrInvalidToken)
	}
	if c.Subject == "" {
		return "", fmt.Errorf("%w: empty subject", ErrInvalidToken)
	}
	return c.Subject, nil
}

func hashNonce(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}
