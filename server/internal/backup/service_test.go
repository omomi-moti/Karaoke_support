package backup

import (
	"context"
	"errors"
	"testing"
	"time"
)

type fakeStorage struct {
	calls       []string
	gotRevision int64
}

func (f *fakeStorage) Create(ctx context.Context, userID string, c Contents) (int64, time.Time, error) {
	f.calls = append(f.calls, "create")
	return 1, time.Now(), nil
}

func (f *fakeStorage) Replace(ctx context.Context, userID string, expectedRevision int64, c Contents) (int64, time.Time, error) {
	f.calls = append(f.calls, "replace")
	f.gotRevision = expectedRevision
	return expectedRevision + 1, time.Now(), nil
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
	valid := Contents{SchemaVersion: SupportedSchemaVersion, TrackCount: 1, SessionCount: 2, Payload: []byte(`{}`)}
	tests := []struct {
		name      string
		cond      Condition
		contents  Contents
		wantErr   error
		wantCalls []string
	}{
		{"If-None-Match は作る", Condition{IfNoneMatch: true}, valid, nil, []string{"create"}},
		{"If-Match は置き換える", Condition{IfMatch: 4}, valid, nil, []string{"replace"}},
		{"知らない schemaVersion は受け付けない", Condition{IfNoneMatch: true}, Contents{SchemaVersion: 2, Payload: []byte(`{}`)}, ErrInvalidBackup, nil},
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
		})
	}
}
