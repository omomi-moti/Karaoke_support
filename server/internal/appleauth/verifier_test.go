package appleauth

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"errors"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	testKID      = "test-kid"
	testAudience = "com.example.app"
	testSubject  = "001234.abcdef"
	testNonce    = "raw-nonce-from-ios"
)

var testNow = time.Date(2026, 11, 10, 12, 0, 0, 0, time.UTC)

type fakeKeys struct {
	key *rsa.PublicKey
}

func (f fakeKeys) KeyfuncCtx(ctx context.Context) jwt.Keyfunc {
	return func(t *jwt.Token) (any, error) {
		if t.Header["kid"] != testKID {
			return nil, errors.New("unknown kid")
		}
		return f.key, nil
	}
}

func newKey(t *testing.T) *rsa.PrivateKey {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	return key
}

func validClaims() jwt.MapClaims {
	return jwt.MapClaims{
		"iss":   issuer,
		"aud":   testAudience,
		"sub":   testSubject,
		"iat":   testNow.Add(-time.Minute).Unix(),
		"exp":   testNow.Add(10 * time.Minute).Unix(),
		"nonce": hashNonce(testNonce),
	}
}

func sign(t *testing.T, method jwt.SigningMethod, key any, kid string, c jwt.MapClaims) string {
	t.Helper()
	tok := jwt.NewWithClaims(method, c)
	tok.Header["kid"] = kid
	s, err := tok.SignedString(key)
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func TestVerify(t *testing.T) {
	appleKey := newKey(t)
	otherKey := newKey(t)
	publicDER, err := x509.MarshalPKIXPublicKey(&appleKey.PublicKey)
	if err != nil {
		t.Fatal(err)
	}

	with := func(key string, value any) jwt.MapClaims {
		c := validClaims()
		if value == nil {
			delete(c, key)
		} else {
			c[key] = value
		}
		return c
	}
	rs256 := func(c jwt.MapClaims) string {
		return sign(t, jwt.SigningMethodRS256, appleKey, testKID, c)
	}

	tests := []struct {
		name     string
		token    string
		rawNonce string
		wantOK   bool
	}{
		{"正しいトークンは通る", rs256(validClaims()), testNonce, true},
		{"発行時刻が 1 分以内の未来なら通る", rs256(with("iat", testNow.Add(30*time.Second).Unix())), testNonce, true},
		{"ほかの鍵の署名", sign(t, jwt.SigningMethodRS256, otherKey, testKID, validClaims()), testNonce, false},
		{"知らない鍵の ID", sign(t, jwt.SigningMethodRS256, appleKey, "other-kid", validClaims()), testNonce, false},
		{"HS256（公開鍵を共通鍵に使う）", sign(t, jwt.SigningMethodHS256, publicDER, testKID, validClaims()), testNonce, false},
		{"none", sign(t, jwt.SigningMethodNone, jwt.UnsafeAllowNoneSignatureType, testKID, validClaims()), testNonce, false},
		{"発行者が違う", rs256(with("iss", "https://evil.example.com")), testNonce, false},
		{"宛先が違う", rs256(with("aud", "com.example.other")), testNonce, false},
		{"宛先にほかのアプリも入っている", rs256(with("aud", []string{testAudience, "com.example.other"})), testNonce, false},
		{"期限切れ", rs256(with("exp", testNow.Add(-2*time.Minute).Unix())), testNonce, false},
		{"期限がない", rs256(with("exp", nil)), testNonce, false},
		{"発行時刻が未来", rs256(with("iat", testNow.Add(2*time.Minute).Unix())), testNonce, false},
		{"発行時刻が 10 分より前", rs256(with("iat", testNow.Add(-11*time.Minute).Unix())), testNonce, false},
		{"発行時刻がない", rs256(with("iat", nil)), testNonce, false},
		{"nonce が違う", rs256(validClaims()), "other-nonce", false},
		{"nonce が空", rs256(validClaims()), "", false},
		{"sub が空", rs256(with("sub", "")), testNonce, false},
		{"トークンの形ではない", "not-a-jwt", testNonce, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			v := NewVerifier(fakeKeys{key: &appleKey.PublicKey}, testAudience)
			v.now = func() time.Time { return testNow }

			sub, err := v.Verify(context.Background(), tt.token, tt.rawNonce)

			if tt.wantOK {
				if err != nil {
					t.Fatalf("err = %v, want nil", err)
				}
				if sub != testSubject {
					t.Fatalf("sub = %q, want %q", sub, testSubject)
				}
				return
			}
			if !errors.Is(err, ErrInvalidToken) {
				t.Fatalf("err = %v, want ErrInvalidToken", err)
			}
			if sub != "" {
				t.Fatalf("sub = %q, want empty", sub)
			}
		})
	}
}
