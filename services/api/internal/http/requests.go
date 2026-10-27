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
	GetRequest(ctx context.Context, id uuid.UUID) (store.Request, error)
	SetRequestStatus(ctx context.Context, id, actor uuid.UUID, to string) error
	ListRequests(ctx context.Context, userID uuid.UUID) (incoming, sent []store.RequestView, err error)
}

func (s *Server) getRequests(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.requests == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	incoming, sent, err := s.requests.ListRequests(r.Context(), uid)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	if incoming == nil {
		incoming = []store.RequestView{}
	}
	if sent == nil {
		sent = []store.RequestView{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"incoming": incoming, "sent": sent})
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
	var raw struct {
		TeacherID string `json:"teacherId"`
		SkillID   string `json:"skillId"`
		Goal      string `json:"goal"`
	}
	if err := json.NewDecoder(r.Body).Decode(&raw); err != nil {
		badRequest(w, "invalid_json")
		return
	}
	n := utf8.RuneCountInString(raw.Goal)
	if n < 8 || n > 280 {
		badRequest(w, "invalid_goal")
		return
	}
	teacherID, err := uuid.Parse(raw.TeacherID)
	if err != nil {
		badRequest(w, "invalid_teacher")
		return
	}
	skillID, err := uuid.Parse(raw.SkillID)
	if err != nil {
		badRequest(w, "invalid_skill")
		return
	}
	in := struct {
		TeacherID uuid.UUID
		SkillID   uuid.UUID
		Goal      string
	}{TeacherID: teacherID, SkillID: skillID, Goal: raw.Goal}
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
	s.notifyNewSessionRequest(r.Context(), req, uid)
	writeJSON(w, http.StatusCreated, req)
}

func (s *Server) notifyNewSessionRequest(ctx context.Context, req store.Request, learnerID uuid.UUID) {
	skill := "a skill"
	if s.notifications != nil {
		if name, err := s.notifications.SkillName(ctx, req.SkillID); err == nil && name != "" {
			skill = name
		}
	}
	learner := s.displayName(ctx, learnerID)
	title, body := sessionRequestCopy(learner, skill)
	s.notifyUser(ctx, req.TeacherID, "session_request", req.ID, title, body)
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
	req, err := s.requests.GetRequest(r.Context(), id)
	if err != nil {
		if errors.Is(err, store.ErrNoSuchRequest) {
			writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	if err := s.requests.SetRequestStatus(r.Context(), id, uid, "accepted"); err != nil {
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
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	s.notifyRequestAccepted(r.Context(), req)
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) notifyRequestAccepted(ctx context.Context, req store.Request) {
	skill := "a skill"
	if s.notifications != nil {
		if name, err := s.notifications.SkillName(ctx, req.SkillID); err == nil && name != "" {
			skill = name
		}
	}
	teacher := s.displayName(ctx, req.TeacherID)
	title, body := requestAcceptedCopy(teacher, skill)
	s.notifyUser(ctx, req.LearnerID, "request_accepted", req.ID, title, body)
}

func (s *Server) declineRequest(w http.ResponseWriter, r *http.Request) {
	s.setRequestStatus(w, r, "declined")
}

func (s *Server) cancelRequest(w http.ResponseWriter, r *http.Request) {
	s.setRequestStatus(w, r, "cancelled")
}
