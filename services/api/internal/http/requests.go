package http

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"unicode/utf8"

	"github.com/google/uuid"

	"knowmates/services/api/internal/store"
)

// RequestStore handles learning request lifecycle.
type RequestStore interface {
	CreateRequest(ctx context.Context, learner, teacher, skill uuid.UUID, goal string) (store.Request, error)
	SetRequestStatus(ctx context.Context, id, actor uuid.UUID, to string) error
}

func (s *Server) postRequest(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.requests == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	var in struct {
		TeacherID uuid.UUID `json:"teacherId"`
		SkillID   uuid.UUID `json:"skillId"`
		Goal      string    `json:"goal"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		badRequest(w, "invalid_json")
		return
	}
	n := utf8.RuneCountInString(in.Goal)
	if n < 8 || n > 280 {
		badRequest(w, "invalid_json")
		return
	}
	req, err := s.requests.CreateRequest(r.Context(), uid, in.TeacherID, in.SkillID, in.Goal)
	if errors.Is(err, store.ErrConflict) {
		writeJSON(w, http.StatusConflict, map[string]string{"error": "conflict"})
		return
	}
	if errors.Is(err, store.ErrForbidden) {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "forbidden"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	writeJSON(w, http.StatusCreated, req)
}

func (s *Server) setRequestStatus(w http.ResponseWriter, r *http.Request, to string) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.requests == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		badRequest(w, "invalid_json")
		return
	}
	err = s.requests.SetRequestStatus(r.Context(), id, uid, to)
	if errors.Is(err, store.ErrNoSuchRequest) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return
	}
	if errors.Is(err, store.ErrForbidden) {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "forbidden"})
		return
	}
	if errors.Is(err, store.ErrConflict) {
		writeJSON(w, http.StatusConflict, map[string]string{"error": "conflict"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) acceptRequest(w http.ResponseWriter, r *http.Request) {
	s.setRequestStatus(w, r, "accepted")
}

func (s *Server) declineRequest(w http.ResponseWriter, r *http.Request) {
	s.setRequestStatus(w, r, "declined")
}

func (s *Server) cancelRequest(w http.ResponseWriter, r *http.Request) {
	s.setRequestStatus(w, r, "cancelled")
}
