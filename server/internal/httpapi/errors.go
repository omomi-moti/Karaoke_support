package httpapi

import (
	"encoding/json"
	"log/slog"
	"net/http"
)

var errorCodes = map[int]string{
	http.StatusBadRequest:            "invalid_request",
	http.StatusUnauthorized:          "unauthorized",
	http.StatusRequestEntityTooLarge: "request_too_large",
	http.StatusInternalServerError:   "internal",
}

// WriteJSON は、v を JSON にして status で返す。
func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		slog.Error("write json response", "err", err)
	}
}

// WriteError は、{"error": "..."} の形で status を返す。
// 返事には決まった短い文だけを入れ、詳しいことは呼ぶ側がログに出す。
func WriteError(w http.ResponseWriter, status int) {
	code, ok := errorCodes[status]
	if !ok {
		code = "internal"
	}
	WriteJSON(w, status, map[string]string{"error": code})
}
