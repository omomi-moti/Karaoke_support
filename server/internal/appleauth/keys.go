package appleauth

import (
	"context"
	"time"

	"github.com/MicahParks/keyfunc/v3"
	"golang.org/x/time/rate"
)

const appleKeysURL = "https://appleid.apple.com/auth/keys"

// NewAppleKeys は、Apple の公開鍵を取ってキャッシュする KeySource を返す。
// 知らない鍵の ID が来たときの取り直しは 5 分に 1 回まで。起動のときに Apple に届かなくてもエラーにしない。
// ctx が終わると、鍵を取り直す裏の処理も止まる。
func NewAppleKeys(ctx context.Context) (KeySource, error) {
	return keyfunc.NewDefaultOverrideCtx(ctx, []string{appleKeysURL}, keyfunc.Override{
		HTTPTimeout:       5 * time.Second,
		RateLimitWaitMax:  time.Second,
		RefreshUnknownKID: rate.NewLimiter(rate.Every(5*time.Minute), 1),
	})
}
