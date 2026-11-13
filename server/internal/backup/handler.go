package backup

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/omomi-moti/Karaoke_support/server/internal/httpapi"
)

// maxBackupBody は、PUT /v1/backup の本文の上限（NFR-5）。
const maxBackupBody = 5 << 20

type backupService interface {
	Put(ctx context.Context, userID string, cond Condition, c Contents) (int64, time.Time, error)
	Summary(ctx context.Context, userID string) (Summary, error)
	Get(ctx context.Context, userID string) (Backup, error)
	Delete(ctx context.Context, userID string) error
}

// Handler は、バックアップの API の入出力を持つ。どれも httpapi.RequireAuth の内側で呼ぶ。
// 記録の中身（payload）はログにもエラーの返事にも出さない（NFR-3）。
type Handler struct {
	svc backupService
}

// NewHandler は、svc を呼ぶ Handler を返す。
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

type putRequest struct {
	SchemaVersion int             `json:"schemaVersion"`
	TrackCount    int             `json:"trackCount"`
	SessionCount  int             `json:"sessionCount"`
	Payload       json.RawMessage `json:"payload"`
}

type putResponse struct {
	Revision  int64     `json:"revision"`
	UpdatedAt time.Time `json:"updatedAt"`
}

type summaryResponse struct {
	Revision      int64     `json:"revision"`
	SchemaVersion int       `json:"schemaVersion"`
	TrackCount    int       `json:"trackCount"`
	SessionCount  int       `json:"sessionCount"`
	UpdatedAt     time.Time `json:"updatedAt"`
}

type backupResponse struct {
	summaryResponse
	Payload json.RawMessage `json:"payload"`
}

// Put は PUT /v1/backup。If-Match: "<版>" か If-None-Match: * が合うときだけ、バックアップを丸ごと置き換える（ADR 0058）。
// 条件がなければ 428、合わなければ 412 で、どちらも置き換えない。
func (h *Handler) Put(w http.ResponseWriter, r *http.Request) {
	userID, ok := httpapi.UserID(r.Context())
	if !ok {
		slog.Error("put backup: no user id in context")
		httpapi.WriteError(w, http.StatusInternalServerError)
		return
	}

	cond, status := parseCondition(r.Header)
	if status != 0 {
		httpapi.WriteError(w, status)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxBackupBody)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	var req putRequest
	if err := dec.Decode(&req); err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			httpapi.WriteError(w, http.StatusRequestEntityTooLarge)
			return
		}
		httpapi.WriteError(w, http.StatusBadRequest)
		return
	}
	if !isJSONObject(req.Payload) {
		httpapi.WriteError(w, http.StatusBadRequest)
		return
	}

	revision, updatedAt, err := h.svc.Put(r.Context(), userID, cond, Contents{
		SchemaVersion: req.SchemaVersion,
		TrackCount:    req.TrackCount,
		SessionCount:  req.SessionCount,
		Payload:       req.Payload,
	})
	switch {
	case err == nil:
		w.Header().Set("ETag", etag(revision))
		w.Header().Set("Cache-Control", "no-store")
		httpapi.WriteJSON(w, http.StatusOK, putResponse{Revision: revision, UpdatedAt: updatedAt.UTC()})
	case errors.Is(err, ErrPreconditionFailed):
		httpapi.WriteError(w, http.StatusPreconditionFailed)
	case errors.Is(err, ErrInvalidBackup):
		slog.Warn("put backup: invalid backup", "schemaVersion", req.SchemaVersion)
		httpapi.WriteError(w, http.StatusBadRequest)
	default:
		slog.Error("put backup", "err", err)
		httpapi.WriteError(w, http.StatusInternalServerError)
	}
}

// Summary は GET /v1/backup/summary。版・件数・日時を返す。ないときは 404。
func (h *Handler) Summary(w http.ResponseWriter, r *http.Request) {
	userID, ok := httpapi.UserID(r.Context())
	if !ok {
		slog.Error("backup summary: no user id in context")
		httpapi.WriteError(w, http.StatusInternalServerError)
		return
	}

	sum, err := h.svc.Summary(r.Context(), userID)
	if errors.Is(err, ErrNotFound) {
		httpapi.WriteError(w, http.StatusNotFound)
		return
	}
	if err != nil {
		slog.Error("backup summary", "err", err)
		httpapi.WriteError(w, http.StatusInternalServerError)
		return
	}

	w.Header().Set("ETag", etag(sum.Revision))
	w.Header().Set("Cache-Control", "no-store")
	httpapi.WriteJSON(w, http.StatusOK, newSummaryResponse(sum))
}

// Get は GET /v1/backup。バックアップを中身ごと返す。ないときは 404。
func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	userID, ok := httpapi.UserID(r.Context())
	if !ok {
		slog.Error("get backup: no user id in context")
		httpapi.WriteError(w, http.StatusInternalServerError)
		return
	}

	b, err := h.svc.Get(r.Context(), userID)
	if errors.Is(err, ErrNotFound) {
		httpapi.WriteError(w, http.StatusNotFound)
		return
	}
	if err != nil {
		slog.Error("get backup", "err", err)
		httpapi.WriteError(w, http.StatusInternalServerError)
		return
	}

	w.Header().Set("ETag", etag(b.Revision))
	w.Header().Set("Cache-Control", "no-store")
	httpapi.WriteJSON(w, http.StatusOK, backupResponse{summaryResponse: newSummaryResponse(b.Summary), Payload: b.Payload})
}

// Delete は DELETE /v1/backup。バックアップを消し、なくても 204 を返す（オフにしたとき、ADR 0058）。
func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, ok := httpapi.UserID(r.Context())
	if !ok {
		slog.Error("delete backup: no user id in context")
		httpapi.WriteError(w, http.StatusInternalServerError)
		return
	}

	if err := h.svc.Delete(r.Context(), userID); err != nil {
		slog.Error("delete backup", "err", err)
		httpapi.WriteError(w, http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func newSummaryResponse(s Summary) summaryResponse {
	return summaryResponse{
		Revision:      s.Revision,
		SchemaVersion: s.SchemaVersion,
		TrackCount:    s.TrackCount,
		SessionCount:  s.SessionCount,
		UpdatedAt:     s.UpdatedAt.UTC(),
	}
}

// parseCondition は、If-Match: "<版>" か If-None-Match: * のどちらか 1 つを読む。
// どちらもなければ 428、両方ある・形が違うときは 400 を、2 つ目の値で返す。読めたら 0 を返す。
func parseCondition(h http.Header) (Condition, int) {
	ifMatch := h.Values("If-Match")
	ifNoneMatch := h.Values("If-None-Match")
	switch {
	case len(ifMatch) == 0 && len(ifNoneMatch) == 0:
		return Condition{}, http.StatusPreconditionRequired
	case len(ifMatch) > 0 && len(ifNoneMatch) > 0, len(ifMatch) > 1, len(ifNoneMatch) > 1:
		return Condition{}, http.StatusBadRequest
	case len(ifNoneMatch) == 1:
		if strings.TrimSpace(ifNoneMatch[0]) != "*" {
			return Condition{}, http.StatusBadRequest
		}
		return Condition{IfNoneMatch: true}, 0
	default:
		revision, ok := parseETag(strings.TrimSpace(ifMatch[0]))
		if !ok {
			return Condition{}, http.StatusBadRequest
		}
		return Condition{IfMatch: revision}, 0
	}
}

// parseETag は、"<1 以上の整数>" の形の ETag から版を読む。
func parseETag(s string) (int64, bool) {
	inner, ok := strings.CutPrefix(s, `"`)
	if !ok {
		return 0, false
	}
	inner, ok = strings.CutSuffix(inner, `"`)
	if !ok || inner == "" || strings.HasPrefix(inner, "+") {
		return 0, false
	}
	revision, err := strconv.ParseInt(inner, 10, 64)
	if err != nil || revision < 1 {
		return 0, false
	}
	return revision, true
}

func etag(revision int64) string {
	return `"` + strconv.FormatInt(revision, 10) + `"`
}

// isJSONObject は、payload が JSON のオブジェクトか（null・配列・文字列などでないか）だけを見る。中身は読まない。
func isJSONObject(payload json.RawMessage) bool {
	return bytes.HasPrefix(bytes.TrimSpace(payload), []byte("{"))
}
