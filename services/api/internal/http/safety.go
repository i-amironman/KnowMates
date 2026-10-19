package http

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"github.com/google/uuid"

	"knowmates/services/api/internal/store"
)

// SafetyStore covers block, report, and account deletion.
type SafetyStore interface {
	BlockUser(ctx context.Context, blocker, blocked uuid.UUID) error
	UnblockUser(ctx context.Context, blocker, blocked uuid.UUID) error
	CreateReport(ctx context.Context, reporter, target uuid.UUID, sessionID *uuid.UUID, reason, details string) error
	DeleteUser(ctx context.Context, userID uuid.UUID) error
}

func (s *Server) postBlock(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.safety == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	var in struct {
		UserID uuid.UUID `json:"userId"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&in); err != nil {
		badRequest(w, "invalid_json")
		return
	}
	if err := s.safety.BlockUser(r.Context(), uid, in.UserID); err != nil {
		if errors.Is(err, store.ErrForbidden) {
			badRequest(w, "forbidden")
			return
		}
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) deleteBlock(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.safety == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	blocked, err := uuid.Parse(r.PathValue("userId"))
	if err != nil {
		badRequest(w, "invalid_id")
		return
	}
	if err := s.safety.UnblockUser(r.Context(), uid, blocked); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) postReport(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.safety == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	var in struct {
		UserID    uuid.UUID  `json:"userId"`
		SessionID *uuid.UUID `json:"sessionId"`
		Reason    string     `json:"reason"`
		Details   string     `json:"details"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&in); err != nil {
		badRequest(w, "invalid_json")
		return
	}
	if err := s.safety.CreateReport(r.Context(), uid, in.UserID, in.SessionID, in.Reason, in.Details); err != nil {
		switch {
		case errors.Is(err, store.ErrForbidden):
			badRequest(w, "forbidden")
		case errors.Is(err, store.ErrNoSuchSession):
			writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		case errors.Is(err, store.ErrConflict):
			writeJSON(w, http.StatusConflict, map[string]string{"error": "conflict"})
		default:
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		}
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) deleteMe(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.safety == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	if err := s.safety.DeleteUser(r.Context(), uid); err != nil {
		if errors.Is(err, store.ErrNoSuchUser) {
			writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
