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
	k, err := keyfunc.NewDefaultOverrideCtx(ctx, []string{appleKeysURL}, keyfunc.Override{
		HTTPTimeout:       5 * time.Second,
		RateLimitWaitMax:  time.Second,
		RefreshUnknownKID: rate.NewLimiter(rate.Every(5*time.Minute), 1),
	})
	if err != nil {
		return nil, err
	}
	return cachedKeys{k}, nil
}

// cachedKeys は、keyfunc に、キャッシュに鍵があるかを答える HasKeys を足したもの。
type cachedKeys struct {
	keyfunc.Keyfunc
}

// HasKeys は、キャッシュに鍵が 1 つでもあるかを返す。Apple には問い合わせない。
func (k cachedKeys) HasKeys(ctx context.Context) bool {
	keys, err := k.Storage().KeyReadAll(ctx)
	return err == nil && len(keys) > 0
}
