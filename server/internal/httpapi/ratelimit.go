package httpapi

import (
	"math"
	"net"
	"net/http"
	"net/netip"
	"strconv"
	"strings"
	"sync"
	"time"

	"golang.org/x/time/rate"
)

const (
	rateLimitPerSecond = 1
	rateLimitBurst     = 30
	rateLimitIdle      = 10 * time.Minute
	rateLimitMaxIPs    = 10000
	rateLimitSweepGap  = time.Minute
	unknownClientKey   = "unknown"
)

// RateLimiter は、相手の IP ごとの回数をトークンバケットで数え、超えたら 429 を返す（ADR 0063）。
// インスタンスは 1 台なので、回数はメモリにだけ持つ（ADR 0051）。
type RateLimiter struct {
	mu        sync.Mutex
	clients   map[string]*rateLimitClient
	now       func() time.Time
	lastSweep time.Time
}

type rateLimitClient struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

// NewRateLimiter は、IP ごとに毎秒 1 回分たまり、30 回までためられる RateLimiter を返す。
func NewRateLimiter() *RateLimiter {
	return newRateLimiter(time.Now)
}

func newRateLimiter(now func() time.Time) *RateLimiter {
	return &RateLimiter{clients: map[string]*rateLimitClient{}, now: now, lastSweep: now()}
}

// Wrap は、回数を超えた相手には 429 と Retry-After を返し、next を呼ばないハンドラーを返す。
func (l *RateLimiter) Wrap(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if wait, ok := l.allow(clientKey(r)); !ok {
			w.Header().Set("Retry-After", strconv.Itoa(max(1, int(math.Ceil(wait.Seconds())))))
			WriteError(w, http.StatusTooManyRequests)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// allow は、key の相手が今 1 回使えるかを返す。使えないときは、次に使えるまでの時間も返す。
// 覚えている相手が上限に達していたら、新しい相手は、古い相手を消す次の掃除まで通さない。
func (l *RateLimiter) allow(key string) (time.Duration, bool) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	l.sweep(now)
	c, ok := l.clients[key]
	if !ok {
		if len(l.clients) >= rateLimitMaxIPs {
			return l.lastSweep.Add(rateLimitSweepGap).Sub(now), false
		}
		c = &rateLimitClient{limiter: rate.NewLimiter(rateLimitPerSecond, rateLimitBurst)}
		l.clients[key] = c
	}
	c.lastSeen = now
	if c.limiter.AllowN(now, 1) {
		return 0, true
	}
	missing := 1 - c.limiter.TokensAt(now)
	return time.Duration(missing / rateLimitPerSecond * float64(time.Second)), false
}

// sweep は、1 分に 1 回まで、使われなくなって 10 分たった相手を消す。
func (l *RateLimiter) sweep(now time.Time) {
	if now.Sub(l.lastSweep) < rateLimitSweepGap {
		return
	}
	l.lastSweep = now
	for key, c := range l.clients {
		if now.Sub(c.lastSeen) >= rateLimitIdle {
			delete(l.clients, key)
		}
	}
}

// clientKey は、回数を数える相手の名前を返す。X-Forwarded-For のいちばん右（Cloud Run が足したもの）、
// なければ RemoteAddr を使う。左側は相手が書き換えられるので使わない（ADR 0063）。
// IPv6 は上の 64 ビットを 1 つの相手とし、読めない値は 1 つの共通の相手にまとめる。
func clientKey(r *http.Request) string {
	host := ""
	if values := r.Header.Values("X-Forwarded-For"); len(values) > 0 {
		parts := strings.Split(values[len(values)-1], ",")
		host = strings.TrimSpace(parts[len(parts)-1])
	} else if h, _, err := net.SplitHostPort(r.RemoteAddr); err == nil {
		host = h
	}
	addr, err := netip.ParseAddr(host)
	if err != nil {
		return unknownClientKey
	}
	addr = addr.WithZone("").Unmap()
	if addr.Is4() {
		return addr.String()
	}
	prefix, err := addr.Prefix(64)
	if err != nil {
		return unknownClientKey
	}
	return prefix.String()
}
