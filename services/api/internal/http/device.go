package http

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/google/uuid"
)

// DeviceStore saves FCM registration tokens.
type DeviceStore interface {
	UpsertDeviceToken(ctx context.Context, userID uuid.UUID, token string) error
	LatestDeviceToken(ctx context.Context, userID uuid.UUID) (string, error)
}

func (s *Server) postMeDevice(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.devices == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	var in struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&in); err != nil {
		badRequest(w, "invalid_json")
		return
	}
	if in.Token == "" {
		badRequest(w, "invalid_token")
		return
	}
	if err := s.devices.UpsertDeviceToken(r.Context(), uid, in.Token); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
