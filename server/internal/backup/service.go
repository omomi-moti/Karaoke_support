package backup

import (
	"context"
	"errors"
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
// 合わないときは何もせず ErrPreconditionFailed を返す。
func (s *Service) Put(ctx context.Context, userID string, cond Condition, c Contents) (int64, time.Time, error) {
	if c.SchemaVersion != SupportedSchemaVersion || c.TrackCount < 0 || c.SessionCount < 0 {
		return 0, time.Time{}, ErrInvalidBackup
	}
	if cond.IfNoneMatch {
		return s.store.Create(ctx, userID, c)
	}
	if cond.IfMatch < 1 {
		return 0, time.Time{}, ErrInvalidBackup
	}
	return s.store.Replace(ctx, userID, cond.IfMatch, c)
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
