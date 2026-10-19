package http

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/google/uuid"

	"knowmates/services/api/internal/store"
)

// BookingStore schedules and completes learning sessions.
type BookingStore interface {
	Schedule(ctx context.Context, requestID, actor uuid.UUID, start, end time.Time, meetingURL string) (store.Session, error)
	Complete(ctx context.Context, sessionID, actor uuid.UUID) (string, error)
	CancelSession(ctx context.Context, sessionID, actor uuid.UUID) error
	Wallet(ctx context.Context, userID uuid.UUID) (store.Wallet, error)
	ListSessions(ctx context.Context, userID uuid.UUID) ([]store.SessionView, error)
}

func (s *Server) getSessions(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.bookings == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	list, err := s.bookings.ListSessions(r.Context(), uid)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	if list == nil {
		list = []store.SessionView{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"sessions": list})
}

func (s *Server) postSession(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.bookings == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	var in struct {
		RequestID  uuid.UUID `json:"requestId"`
		StartsAt   time.Time `json:"startsAt"`
		EndsAt     time.Time `json:"endsAt"`
		MeetingURL string    `json:"meetingUrl"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		badRequest(w, "invalid_json")
		return
	}
	sess, err := s.bookings.Schedule(r.Context(), in.RequestID, uid, in.StartsAt, in.EndsAt, in.MeetingURL)
	if errors.Is(err, store.ErrBadMeetingURL) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "bad_meeting_url"})
		return
	}
	if errors.Is(err, store.ErrInsufficientCredits) {
		writeJSON(w, http.StatusPaymentRequired, map[string]string{"error": "insufficient_credits"})
		return
	}
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
	writeJSON(w, http.StatusCreated, sess)
}

func (s *Server) completeSession(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.bookings == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		badRequest(w, "invalid_json")
		return
	}
	status, err := s.bookings.Complete(r.Context(), id, uid)
	if errors.Is(err, store.ErrNoSuchSession) {
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
	writeJSON(w, http.StatusOK, map[string]string{"status": status})
}

func (s *Server) cancelSession(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.bookings == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		badRequest(w, "invalid_json")
		return
	}
	err = s.bookings.CancelSession(r.Context(), id, uid)
	if errors.Is(err, store.ErrNoSuchSession) {
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

func (s *Server) getWallet(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.bookings == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	wallet, err := s.bookings.Wallet(r.Context(), uid)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	writeJSON(w, http.StatusOK, wallet)
}
