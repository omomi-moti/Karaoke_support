// Package account は、アカウントとサーバーのトークンを扱う（ADR 0054）。
package account

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
)

const (
	tokenPrefix = "klog_"
	tokenBytes  = 32
)

// newToken は、サーバーのトークンのそのままの値と、DB に置くハッシュを返す。
// そのままの値は利用者に 1 回だけ返し、どこにも保存しない。
func newToken() (raw string, hash []byte) {
	b := make([]byte, tokenBytes)
	rand.Read(b)
	raw = tokenPrefix + base64.RawURLEncoding.EncodeToString(b)
	return raw, hashToken(raw)
}

// hashToken は、トークンの SHA-256 を返す。DB との照合はこの値で行う。
func hashToken(raw string) []byte {
	sum := sha256.Sum256([]byte(raw))
	return sum[:]
}
