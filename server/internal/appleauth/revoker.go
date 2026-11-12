package appleauth

import (
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	appleBaseURL       = "https://appleid.apple.com"
	clientSecretTTL    = 5 * time.Minute
	revokerHTTPTimeout = 10 * time.Second
	maxAppleResponse   = 64 << 10
)

// ErrInvalidCode は、Apple が認可コードを受け付けなかった（期限切れ・使い回し）ことを表す。
// 利用者がやり直せば済むので、サーバーの側の失敗とは分ける（ADR 0057）。
var ErrInvalidCode = errors.New("apple authorization code invalid")

// Revoker は、iOS から来た認可コードで、Apple のトークンを取り消す（ADR 0057）。
type Revoker struct {
	client   *http.Client
	baseURL  string
	clientID string
	teamID   string
	keyID    string
	key      *ecdsa.PrivateKey
	now      func() time.Time
}

// NewRevoker は、Sign in with Apple の鍵（.p8 の PEM）で client_secret を作る Revoker を返す。
// clientID はアプリのバンドル ID。
func NewRevoker(clientID, teamID, keyID string, pemKey []byte) (*Revoker, error) {
	key, err := jwt.ParseECPrivateKeyFromPEM(pemKey)
	if err != nil {
		return nil, fmt.Errorf("parse apple sign-in key: %w", err)
	}
	return &Revoker{
		client:   &http.Client{Timeout: revokerHTTPTimeout},
		baseURL:  appleBaseURL,
		clientID: clientID,
		teamID:   teamID,
		keyID:    keyID,
		key:      key,
		now:      time.Now,
	}, nil
}

// RevokeWithCode は、認可コードを Apple のトークンに替え、そのトークンを取り消す。
// Apple がコードを受け付けなければ ErrInvalidCode を包んだエラーを返す。
// エラーには、コード・トークン・client_secret を入れない。
func (r *Revoker) RevokeWithCode(ctx context.Context, code string) error {
	secret, err := r.clientSecret()
	if err != nil {
		return err
	}

	var tokens struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
	}
	if err := r.post(ctx, "/auth/token", url.Values{
		"client_id":     {r.clientID},
		"client_secret": {secret},
		"code":          {code},
		"grant_type":    {"authorization_code"},
	}, &tokens); err != nil {
		return fmt.Errorf("exchange code: %w", err)
	}

	token, hint := tokens.RefreshToken, "refresh_token"
	if token == "" {
		token, hint = tokens.AccessToken, "access_token"
	}
	if token == "" {
		return errors.New("exchange code: apple returned no token")
	}

	if err := r.post(ctx, "/auth/revoke", url.Values{
		"client_id":       {r.clientID},
		"client_secret":   {secret},
		"token":           {token},
		"token_type_hint": {hint},
	}, nil); err != nil {
		return fmt.Errorf("revoke token: %w", err)
	}
	return nil
}

func (r *Revoker) clientSecret() (string, error) {
	now := r.now()
	t := jwt.NewWithClaims(jwt.SigningMethodES256, jwt.RegisteredClaims{
		Issuer:    r.teamID,
		Subject:   r.clientID,
		Audience:  jwt.ClaimStrings{issuer},
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(clientSecretTTL)),
	})
	t.Header["kid"] = r.keyID
	secret, err := t.SignedString(r.key)
	if err != nil {
		return "", fmt.Errorf("sign client secret: %w", err)
	}
	return secret, nil
}

// post は、form を送り、200 なら返事を out に読む（out が nil なら読まない）。
// 400 で invalid_grant なら ErrInvalidCode を返す。
func (r *Revoker) post(ctx context.Context, path string, form url.Values, out any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, r.baseURL+path, strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	res, err := r.client.Do(req)
	if err != nil {
		return fmt.Errorf("request apple: %w", err)
	}
	defer res.Body.Close()
	body, err := io.ReadAll(io.LimitReader(res.Body, maxAppleResponse))
	if err != nil {
		return fmt.Errorf("read apple response: %w", err)
	}

	if res.StatusCode != http.StatusOK {
		var e struct {
			Error string `json:"error"`
		}
		_ = json.Unmarshal(body, &e)
		if res.StatusCode == http.StatusBadRequest && e.Error == "invalid_grant" {
			return ErrInvalidCode
		}
		return fmt.Errorf("apple returned %d %q", res.StatusCode, e.Error)
	}
	if out == nil {
		return nil
	}
	if err := json.Unmarshal(body, out); err != nil {
		return fmt.Errorf("decode apple response: %w", err)
	}
	return nil
}
