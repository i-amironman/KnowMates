package http

import (
	"context"
	"net/http"

	"github.com/google/uuid"

	"knowmates/services/api/internal/store"
)

// NotificationStore persists in-app alerts.
type NotificationStore interface {
	InsertNotification(ctx context.Context, userID uuid.UUID, kind string, refID uuid.UUID, title, body string) error
	UnreadNotificationCount(ctx context.Context, userID uuid.UUID) (int, error)
	MarkNotificationsRead(ctx context.Context, userID uuid.UUID) error
	ListNotifications(ctx context.Context, userID uuid.UUID, limit int) ([]store.Notification, error)
	DisplayName(ctx context.Context, userID uuid.UUID) (string, error)
	SkillName(ctx context.Context, skillID uuid.UUID) (string, error)
}

func (s *Server) getNotifications(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.notifications == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	list, err := s.notifications.ListNotifications(r.Context(), uid, 30)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	if list == nil {
		list = []store.Notification{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"notifications": list})
}

func (s *Server) getUnreadNotificationCount(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.notifications == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	n, err := s.notifications.UnreadNotificationCount(r.Context(), uid)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"unread": n})
}

func (s *Server) postNotificationsRead(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.notifications == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	if err := s.notifications.MarkNotificationsRead(r.Context(), uid); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
