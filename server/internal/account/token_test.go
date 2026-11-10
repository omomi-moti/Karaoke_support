package account

import (
	"bytes"
	"crypto/sha256"
	"strings"
	"testing"
)

func TestNewToken(t *testing.T) {
	raw, hash := newToken()

	if !strings.HasPrefix(raw, tokenPrefix) {
		t.Fatalf("raw = %q, want prefix %q", raw, tokenPrefix)
	}
	if got, want := len(raw), len(tokenPrefix)+43; got != want {
		t.Fatalf("len(raw) = %d, want %d（32 バイトを URL で使える文字にすると 43 文字）", got, want)
	}
	sum := sha256.Sum256([]byte(raw))
	if !bytes.Equal(hash, sum[:]) {
		t.Fatal("hash は raw の SHA-256 でなければいけない")
	}

	other, _ := newToken()
	if other == raw {
		t.Fatal("2 回作ったトークンが同じになった")
	}
}
