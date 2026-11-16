package httpapi

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// limited は、時計を差し替えた RateLimiter と、通った回数を数えるハンドラーを返す。
func limited(now *time.Time) (http.Handler, *atomic.Int64) {
	var calls atomic.Int64
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		w.WriteHeader(http.StatusOK)
	})
	return newRateLimiter(func() time.Time { return *now }).Wrap(next), &calls
}

func request(h http.Handler, forwardedFor string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodGet, "/v1/me", nil)
	if forwardedFor != "" {
		req.Header.Set("X-Forwarded-For", forwardedFor)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

// TestRateLimiterBurst は、続けて 30 回までは通し、31 回目は 429 と Retry-After を返して後ろを呼ばないことを確かめる。
func TestRateLimiterBurst(t *testing.T) {
	now := time.Date(2026, 11, 16, 0, 0, 0, 0, time.UTC)
	h, calls := limited(&now)
	for i := range 30 {
		if rec := request(h, "203.0.113.1"); rec.Code != http.StatusOK {
			t.Fatalf("%d 回目: status = %d, want 200", i+1, rec.Code)
		}
	}
	rec := request(h, "203.0.113.1")
	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("31 回目: status = %d, want 429", rec.Code)
	}
	if got := rec.Header().Get("Retry-After"); got != "1" {
		t.Fatalf("Retry-After = %q, want \"1\"", got)
	}
	if got := rec.Body.String(); got != "{\"error\":\"too_many_requests\"}\n" {
		t.Fatalf("body = %q", got)
	}
	if calls.Load() != 30 {
		t.Fatalf("後ろのハンドラーを %d 回呼んだ, want 30", calls.Load())
	}
}

// TestRateLimiterRefill は、時間がたつと毎秒 1 回分ずつ、30 回まで戻ることを確かめる。
func TestRateLimiterRefill(t *testing.T) {
	now := time.Date(2026, 11, 16, 0, 0, 0, 0, time.UTC)
	h, _ := limited(&now)
	for range 30 {
		request(h, "203.0.113.1")
	}

	now = now.Add(time.Second)
	if rec := request(h, "203.0.113.1"); rec.Code != http.StatusOK {
		t.Fatalf("1 秒後: status = %d, want 200", rec.Code)
	}
	if rec := request(h, "203.0.113.1"); rec.Code != http.StatusTooManyRequests {
		t.Fatalf("1 秒後の 2 回目: status = %d, want 429", rec.Code)
	}

	now = now.Add(time.Hour)
	for i := range 30 {
		if rec := request(h, "203.0.113.1"); rec.Code != http.StatusOK {
			t.Fatalf("1 時間後の %d 回目: status = %d, want 200（30 回まで戻る）", i+1, rec.Code)
		}
	}
	if rec := request(h, "203.0.113.1"); rec.Code != http.StatusTooManyRequests {
		t.Fatalf("1 時間後の 31 回目: status = %d, want 429（30 回より多くはためない）", rec.Code)
	}
}

// TestRateLimiterPerClient は、相手ごとに数え、ほかの相手の回数に影響しないことを確かめる。
func TestRateLimiterPerClient(t *testing.T) {
	now := time.Date(2026, 11, 16, 0, 0, 0, 0, time.UTC)
	h, _ := limited(&now)
	for range 31 {
		request(h, "203.0.113.1")
	}
	if rec := request(h, "203.0.113.2"); rec.Code != http.StatusOK {
		t.Fatalf("ほかの相手: status = %d, want 200", rec.Code)
	}
}

// TestRateLimiterIgnoresForgedForwardedFor は、X-Forwarded-For の左側を毎回変えても、ほかの相手として数えさせないことを確かめる。
func TestRateLimiterIgnoresForgedForwardedFor(t *testing.T) {
	now := time.Date(2026, 11, 16, 0, 0, 0, 0, time.UTC)
	h, _ := limited(&now)
	for i := range 30 {
		request(h, fmt.Sprintf("198.51.100.%d, 203.0.113.1", i))
	}
	if rec := request(h, "198.51.100.200, 203.0.113.1"); rec.Code != http.StatusTooManyRequests {
		t.Fatalf("左側を変えた 31 回目: status = %d, want 429", rec.Code)
	}
}

// TestRateLimiterSweepAndCap は、覚えている相手が上限に達したら新しい相手を通さず、
// 使われなくなって 10 分たった相手を消した後は、また通すことを確かめる。
func TestRateLimiterSweepAndCap(t *testing.T) {
	now := time.Date(2026, 11, 16, 0, 0, 0, 0, time.UTC)
	l := newRateLimiter(func() time.Time { return now })
	h := l.Wrap(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	for i := range rateLimitMaxIPs {
		request(h, fmt.Sprintf("10.%d.%d.%d", i>>16&0xff, i>>8&0xff, i&0xff))
	}

	rec := request(h, "203.0.113.1")
	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("上限のとき: status = %d, want 429", rec.Code)
	}
	if got := rec.Header().Get("Retry-After"); got != "60" {
		t.Fatalf("上限のときの Retry-After = %q, want \"60\"（次の掃除まで）", got)
	}
	if rec := request(h, "10.0.0.0"); rec.Code != http.StatusOK {
		t.Fatalf("上限のときも、覚えている相手は通す: status = %d", rec.Code)
	}

	now = now.Add(5 * time.Minute)
	request(h, "10.0.0.1")
	now = now.Add(5 * time.Minute)
	if rec := request(h, "203.0.113.1"); rec.Code != http.StatusOK {
		t.Fatalf("10 分たった後: status = %d, want 200", rec.Code)
	}
	if _, ok := l.clients["10.0.0.1"]; !ok || len(l.clients) != 2 {
		t.Fatalf("覚えている相手 = %d 件、10.0.0.1 あり = %v。5 分前に使った相手と新しい相手の 2 件だけが残るはず", len(l.clients), ok)
	}
}

// TestRateLimiterConcurrent は、同じ相手から同時に呼ばれても、ちょうど 30 回だけ通すことを確かめる（-race で流す）。
func TestRateLimiterConcurrent(t *testing.T) {
	now := time.Date(2026, 11, 16, 0, 0, 0, 0, time.UTC)
	h, calls := limited(&now)
	var wg sync.WaitGroup
	for range 100 {
		wg.Go(func() { request(h, "203.0.113.1") })
	}
	wg.Wait()
	if calls.Load() != 30 {
		t.Fatalf("通った回数 = %d, want 30", calls.Load())
	}
}

func TestClientKey(t *testing.T) {
	tests := []struct {
		name         string
		remoteAddr   string
		forwardedFor []string
		want         string
	}{
		{"X-Forwarded-For がなければ RemoteAddr", "192.0.2.1:1234", nil, "192.0.2.1"},
		{"1 つだけならそれ", "192.0.2.1:1234", []string{"203.0.113.1"}, "203.0.113.1"},
		{"いくつかあれば、いちばん右", "192.0.2.1:1234", []string{"198.51.100.7, 203.0.113.1"}, "203.0.113.1"},
		{"行が分かれていれば、最後の行のいちばん右", "192.0.2.1:1234", []string{"198.51.100.7", "203.0.113.1"}, "203.0.113.1"},
		{"IPv6 は上の 64 ビットで数える", "192.0.2.1:1234", []string{"2001:db8:1:2:aaaa::1"}, "2001:db8:1:2::/64"},
		{"IPv6 の下の 64 ビットが違っても同じ相手", "192.0.2.1:1234", []string{"2001:db8:1:2:bbbb::9"}, "2001:db8:1:2::/64"},
		{"IPv4 を写した IPv6 は IPv4 として数える", "192.0.2.1:1234", []string{"::ffff:203.0.113.1"}, "203.0.113.1"},
		{"ゾーンの付いた IPv6", "[fe80::1%en0]:1234", nil, "fe80::/64"},
		{"読めない値は共通の相手", "192.0.2.1:1234", []string{"not-an-ip"}, unknownClientKey},
		{"空の値は共通の相手", "192.0.2.1:1234", []string{""}, unknownClientKey},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/", nil)
			req.RemoteAddr = tt.remoteAddr
			for _, v := range tt.forwardedFor {
				req.Header.Add("X-Forwarded-For", v)
			}
			if got := clientKey(req); got != tt.want {
				t.Fatalf("clientKey = %q, want %q", got, tt.want)
			}
		})
	}
}
