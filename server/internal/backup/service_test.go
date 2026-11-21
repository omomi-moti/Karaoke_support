package backup

import (
	"bytes"
	"context"
	"errors"
	"testing"
	"time"
)

type fakeStorage struct {
	calls       []string
	gotRevision int64
	gotContents Contents
	// writeErr は、Create と Replace が返すエラー。条件が合わなかったときをまねる。
	writeErr error
	// currentHash と currentRevision は、今のバックアップの中身のハッシュと版。
	currentHash     []byte
	currentRevision int64
	findErr         error
}

func (f *fakeStorage) Create(ctx context.Context, userID string, c Contents) (int64, time.Time, error) {
	f.calls = append(f.calls, "create")
	f.gotContents = c
	if f.writeErr != nil {
		return 0, time.Time{}, f.writeErr
	}
	return 1, time.Now(), nil
}

func (f *fakeStorage) Replace(ctx context.Context, userID string, expectedRevision int64, c Contents) (int64, time.Time, error) {
	f.calls = append(f.calls, "replace")
	f.gotRevision = expectedRevision
	f.gotContents = c
	if f.writeErr != nil {
		return 0, time.Time{}, f.writeErr
	}
	return expectedRevision + 1, time.Now(), nil
}

func (f *fakeStorage) FindSameContents(ctx context.Context, userID string, hash []byte) (int64, time.Time, error) {
	f.calls = append(f.calls, "findSame")
	if f.findErr != nil {
		return 0, time.Time{}, f.findErr
	}
	if f.currentHash == nil || !bytes.Equal(hash, f.currentHash) {
		return 0, time.Time{}, ErrNotFound
	}
	return f.currentRevision, time.Now(), nil
}

func (f *fakeStorage) Summary(ctx context.Context, userID string) (Summary, error) {
	return Summary{}, nil
}

func (f *fakeStorage) Get(ctx context.Context, userID string) (Backup, error) {
	return Backup{}, nil
}

func (f *fakeStorage) Delete(ctx context.Context, userID string) error {
	return nil
}

func TestServicePut(t *testing.T) {
	valid := Contents{SchemaVersion: LatestSchemaVersion, TrackCount: 1, SessionCount: 2, Payload: []byte(`{}`)}
	tests := []struct {
		name      string
		cond      Condition
		contents  Contents
		wantErr   error
		wantCalls []string
	}{
		{"If-None-Match は作る", Condition{IfNoneMatch: true}, valid, nil, []string{"create"}},
		{"If-Match は置き換える", Condition{IfMatch: 4}, valid, nil, []string{"replace"}},
		{"前の schemaVersion も受け付ける", Condition{IfNoneMatch: true}, Contents{SchemaVersion: 1, Payload: []byte(`{}`)}, nil, []string{"create"}},
		{"知らない schemaVersion は受け付けない", Condition{IfNoneMatch: true}, Contents{SchemaVersion: LatestSchemaVersion + 1, Payload: []byte(`{}`)}, ErrInvalidBackup, nil},
		{"schemaVersion がなければ受け付けない", Condition{IfNoneMatch: true}, Contents{Payload: []byte(`{}`)}, ErrInvalidBackup, nil},
		{"負の件数は受け付けない", Condition{IfNoneMatch: true}, Contents{SchemaVersion: 1, TrackCount: -1, Payload: []byte(`{}`)}, ErrInvalidBackup, nil},
		{"条件がなければ受け付けない", Condition{}, valid, ErrInvalidBackup, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &fakeStorage{}
			_, _, err := (&Service{store: store}).Put(context.Background(), "u", tt.cond, tt.contents)
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("err = %v, want %v", err, tt.wantErr)
			}
			if len(store.calls) != len(tt.wantCalls) || (len(tt.wantCalls) == 1 && store.calls[0] != tt.wantCalls[0]) {
				t.Fatalf("calls = %v, want %v", store.calls, tt.wantCalls)
			}
			if tt.cond.IfMatch != 0 && tt.wantErr == nil && store.gotRevision != tt.cond.IfMatch {
				t.Fatalf("渡した版 = %d, want %d", store.gotRevision, tt.cond.IfMatch)
			}
			if tt.wantErr == nil && !bytes.Equal(store.gotContents.PayloadSHA256, contentHash(tt.contents)) {
				t.Fatalf("保存するハッシュ = %x, want %x", store.gotContents.PayloadSHA256, contentHash(tt.contents))
			}
		})
	}
}

// TestServicePutSameContents は、条件が合わなくても、今のバックアップと同じ中身なら今の版を返すことを確かめる（ADR 0061）。
func TestServicePutSameContents(t *testing.T) {
	sent := Contents{SchemaVersion: LatestSchemaVersion, TrackCount: 1, SessionCount: 2, Payload: []byte(`{"tracks":[],"sessions":[]}`)}
	other := sent
	other.SessionCount = 3
	dbErr := errors.New("db is down")
	tests := []struct {
		name         string
		cond         Condition
		currentHash  []byte
		findErr      error
		wantRevision int64
		wantErr      error
	}{
		{"古い版で同じ中身なら、今の版を返す", Condition{IfMatch: 4}, contentHash(sent), nil, 5, nil},
		{"もうあるのに If-None-Match で同じ中身なら、今の版を返す", Condition{IfNoneMatch: true}, contentHash(sent), nil, 5, nil},
		{"違う中身なら 412", Condition{IfMatch: 4}, contentHash(other), nil, 0, ErrPreconditionFailed},
		{"今のバックアップのハッシュが空なら 412", Condition{IfMatch: 4}, nil, nil, 0, ErrPreconditionFailed},
		{"同じ中身かを読めなければ、そのエラーを返す", Condition{IfMatch: 4}, contentHash(sent), dbErr, 0, dbErr},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &fakeStorage{writeErr: ErrPreconditionFailed, currentHash: tt.currentHash, currentRevision: 5, findErr: tt.findErr}
			revision, _, err := (&Service{store: store}).Put(context.Background(), "u", tt.cond, sent)
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("err = %v, want %v", err, tt.wantErr)
			}
			if revision != tt.wantRevision {
				t.Fatalf("revision = %d, want %d", revision, tt.wantRevision)
			}
		})
	}
}

// TestServicePutDoesNotCompareOnSuccess は、置き換えられたときは同じ中身かを見に行かないことを確かめる。
func TestServicePutDoesNotCompareOnSuccess(t *testing.T) {
	store := &fakeStorage{}
	valid := Contents{SchemaVersion: LatestSchemaVersion, Payload: []byte(`{}`)}
	if _, _, err := (&Service{store: store}).Put(context.Background(), "u", Condition{IfMatch: 1}, valid); err != nil {
		t.Fatal(err)
	}
	if len(store.calls) != 1 || store.calls[0] != "replace" {
		t.Fatalf("calls = %v, want [replace]", store.calls)
	}
}

func TestContentHash(t *testing.T) {
	base := Contents{SchemaVersion: 1, TrackCount: 1, SessionCount: 2, Payload: []byte(`{"tracks":[],"sessions":[]}`)}
	if got := contentHash(base); len(got) != 32 || !bytes.Equal(got, contentHash(base)) {
		t.Fatalf("同じ中身で同じ 32 バイトにならない: %x", got)
	}
	changes := map[string]func(c *Contents){
		"schemaVersion": func(c *Contents) { c.SchemaVersion = 2 },
		"曲の数":           func(c *Contents) { c.TrackCount = 2 },
		"記録の数":          func(c *Contents) { c.SessionCount = 3 },
		"payload の空白":   func(c *Contents) { c.Payload = []byte(`{"tracks": [],"sessions":[]}`) },
	}
	for name, change := range changes {
		c := base
		change(&c)
		if bytes.Equal(contentHash(c), contentHash(base)) {
			t.Errorf("%s が違うのに同じハッシュになった", name)
		}
	}
}
