package http

import (
	"context"
	"errors"
	"net/http"
	"os"
	"time"

	"github.com/coder/websocket"
	"github.com/google/uuid"

	"knowmates/services/api/internal/call"
	"knowmates/services/api/internal/store"
)

type CallStore interface {
	GetSession(ctx context.Context, id uuid.UUID) (store.Session, error)
	InsertCallMessage(ctx context.Context, sessionID, sender uuid.UUID, body string) (uuid.UUID, time.Time, error)
	CallHistory(ctx context.Context, sessionID uuid.UUID) ([]store.CallMessage, error)
}

func (s *Server) admitCall(w http.ResponseWriter, r *http.Request, sessionID, uid uuid.UUID) (store.Session, uuid.UUID, bool) {
	if s.calls == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return store.Session{}, uuid.Nil, false
	}
	sess, err := s.calls.GetSession(r.Context(), sessionID)
	if errors.Is(err, store.ErrNoSuchSession) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return store.Session{}, uuid.Nil, false
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return store.Session{}, uuid.Nil, false
	}
	participant := uid == sess.LearnerID || uid == sess.TeacherID
	canJoin := call.CanJoin(time.Now(), sess.Status, sess.StartsAt)
	if code := call.AdmissionError(participant, canJoin); code != "" {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": code})
		return store.Session{}, uuid.Nil, false
	}
	peer, err := call.PeerID(sess.LearnerID, sess.TeacherID, uid)
	if err != nil {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "forbidden"})
		return store.Session{}, uuid.Nil, false
	}
	return sess, peer, true
}

func (s *Server) postCallTicket(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	sessionID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		badRequest(w, "invalid_json")
		return
	}
	if _, _, ok := s.admitCall(w, r, sessionID, uid); !ok {
		return
	}
	out := call.TicketJSON(os.Getenv("TURN_SECRET"), os.Getenv("TURN_URLS"), uid, time.Now())
	writeJSON(w, http.StatusOK, out)
}

func (s *Server) getCallWebSocket(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.redis == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	sessionID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		badRequest(w, "invalid_json")
		return
	}
	_, peer, ok := s.admitCall(w, r, sessionID, uid)
	if !ok {
		return
	}
	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		OriginPatterns: []string{"*"},
	})
	if err != nil {
		return
	}
	call.RunSignal(r.Context(), conn, s.redis, s.calls, sessionID, uid, peer)
}
