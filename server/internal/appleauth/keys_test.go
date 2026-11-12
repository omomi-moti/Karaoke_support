package appleauth

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"testing"
	"time"

	"github.com/MicahParks/keyfunc/v3"
	"github.com/golang-jwt/jwt/v5"
)

func TestCachedKeysHasKeys(t *testing.T) {
	key := newKey(t)
	n := base64.RawURLEncoding.EncodeToString(key.N.Bytes())
	e := base64.RawURLEncoding.EncodeToString(big.NewInt(int64(key.E)).Bytes())
	oneKey := fmt.Sprintf(`{"keys":[{"kty":"RSA","kid":%q,"use":"sig","alg":"RS256","n":%q,"e":%q}]}`, testKID, n, e)

	tests := []struct {
		name string
		jwks string
		want bool
	}{
		{"鍵が 1 つある", oneKey, true},
		{"鍵が 1 つもない", `{"keys":[]}`, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			k, err := keyfunc.NewJWKSetJSON(json.RawMessage(tt.jwks))
			if err != nil {
				t.Fatal(err)
			}
			if got := (cachedKeys{k}).HasKeys(context.Background()); got != tt.want {
				t.Fatalf("HasKeys() = %v, want %v", got, tt.want)
			}
		})
	}
}

// TestVerifyWithEmptyKeyfunc は、本物の keyfunc が鍵を 1 つも持たないとき、
// Verify が ErrKeysUnavailable を返すことを確かめる（keyfunc のエラーが jwt.ErrTokenUnverifiable に包まれること）。
func TestVerifyWithEmptyKeyfunc(t *testing.T) {
	k, err := keyfunc.NewJWKSetJSON(json.RawMessage(`{"keys":[]}`))
	if err != nil {
		t.Fatal(err)
	}
	v := NewVerifier(cachedKeys{k}, testAudience)
	v.now = func() time.Time { return testNow }

	token := sign(t, jwt.SigningMethodRS256, newKey(t), testKID, validClaims())
	if _, err := v.Verify(context.Background(), token, testNonce); !errors.Is(err, ErrKeysUnavailable) {
		t.Fatalf("err = %v, want ErrKeysUnavailable", err)
	}
}
