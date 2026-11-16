package backup

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"time"
)

// SupportedSchemaVersion は、受け付けるバックアップの形の版（NFR-7）。
const SupportedSchemaVersion = 1

// ErrNotFound は、バックアップがないことを表す（404 にする）。
var ErrNotFound = errors.New("backup not found")

// ErrPreconditionFailed は、送る側が見た版と、サーバーのバックアップの版が合わないことを表す（412 にする、ADR 0058）。
var ErrPreconditionFailed = errors.New("backup revision does not match")

// ErrInvalidBackup は、受け付けない中身を表す（400 にする）。知らない schemaVersion・負の件数など。
var ErrInvalidBackup = errors.New("invalid backup")

// Condition は、置き換えてよい条件。IfNoneMatch か IfMatch のどちらか 1 つだけを持つ。
type Condition struct {
	// IfNoneMatch は、バックアップがまだないときだけ作る（If-None-Match: *）。
	IfNoneMatch bool
	// IfMatch は、バックアップの版がこの値のときだけ置き換える（If-Match: "<版>"）。
	IfMatch int64
}

type storage interface {
	Create(ctx context.Context, userID string, c Contents) (int64, time.Time, error)
	Replace(ctx context.Context, userID string, expectedRevision int64, c Contents) (int64, time.Time, error)
	FindSameContents(ctx context.Context, userID string, hash []byte) (int64, time.Time, error)
	Summary(ctx context.Context, userID string) (Summary, error)
	Get(ctx context.Context, userID string) (Backup, error)
	Delete(ctx context.Context, userID string) error
}

// Service は、バックアップを置き換える・読む・消すルールを持つ。
type Service struct {
	store storage
}

// NewService は、store に保存する Service を返す。
func NewService(store *Store) *Service {
	return &Service{store: store}
}

// Put は、cond が合うときだけ userID のバックアップを c で置き換え、新しい版と日時を返す。
// 合わなくても、c が今のバックアップと同じ中身なら、置き換えずに今の版と日時を返す。送った端末が返事を受け取れずに、
// 古い版のまま同じ中身を送り直したときに、412 にしないため（ADR 0061）。違う中身なら何もせず ErrPreconditionFailed を返す。
func (s *Service) Put(ctx context.Context, userID string, cond Condition, c Contents) (int64, time.Time, error) {
	if c.SchemaVersion != SupportedSchemaVersion || c.TrackCount < 0 || c.SessionCount < 0 {
		return 0, time.Time{}, ErrInvalidBackup
	}
	if !cond.IfNoneMatch && cond.IfMatch < 1 {
		return 0, time.Time{}, ErrInvalidBackup
	}
	c.PayloadSHA256 = contentHash(c)
	var revision int64
	var updatedAt time.Time
	var err error
	if cond.IfNoneMatch {
		revision, updatedAt, err = s.store.Create(ctx, userID, c)
	} else {
		revision, updatedAt, err = s.store.Replace(ctx, userID, cond.IfMatch, c)
	}
	if !errors.Is(err, ErrPreconditionFailed) {
		return revision, updatedAt, err
	}
	revision, updatedAt, err = s.store.FindSameContents(ctx, userID, c.PayloadSHA256)
	if errors.Is(err, ErrNotFound) {
		return 0, time.Time{}, ErrPreconditionFailed
	}
	return revision, updatedAt, err
}

// contentHash は、schemaVersion・件数・受け取ったままの payload のバイト列の SHA-256（ADR 0061）。
// jsonb に入れると書式が変わるので、入れる前のバイト列から作る。
func contentHash(c Contents) []byte {
	h := sha256.New()
	fmt.Fprintf(h, "%d\n%d\n%d\n", c.SchemaVersion, c.TrackCount, c.SessionCount)
	h.Write(c.Payload)
	return h.Sum(nil)
}

// Summary は、userID のバックアップの版・件数・日時を返す。ないときは ErrNotFound を返す。
func (s *Service) Summary(ctx context.Context, userID string) (Summary, error) {
	return s.store.Summary(ctx, userID)
}

// Get は、userID のバックアップを中身ごと返す。ないときは ErrNotFound を返す。
func (s *Service) Get(ctx context.Context, userID string) (Backup, error) {
	return s.store.Get(ctx, userID)
}

// Delete は、userID のバックアップを消す。ないときもエラーにしない。
func (s *Service) Delete(ctx context.Context, userID string) error {
	return s.store.Delete(ctx, userID)
}
