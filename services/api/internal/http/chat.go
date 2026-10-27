package http

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"github.com/google/uuid"

	"knowmates/services/api/internal/store"
)

// ChatStore handles E2E chat threads (server stores ciphertext only).
type ChatStore interface {
	ListChatThreads(ctx context.Context, userID uuid.UUID) ([]store.ChatThreadView, error)
	GetChatThread(ctx context.Context, threadID, userID uuid.UUID) (store.ChatThreadView, error)
	UpsertChatPublicKey(ctx context.Context, threadID, userID uuid.UUID, publicKey string) error
	InsertChatMessage(ctx context.Context, threadID, sender uuid.UUID, ciphertext, nonce string) (store.ChatMessageRow, error)
	ListChatMessages(ctx context.Context, threadID, userID uuid.UUID, afterID *uuid.UUID) ([]store.ChatMessageRow, error)
	ChatCounterpart(ctx context.Context, threadID, sender uuid.UUID) (uuid.UUID, error)
}

func (s *Server) getChats(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.chats == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	list, err := s.chats.ListChatThreads(r.Context(), uid)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	if list == nil {
		list = []store.ChatThreadView{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"threads": list})
}

func (s *Server) getChat(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.chats == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		badRequest(w, "invalid_json")
		return
	}
	thread, err := s.chats.GetChatThread(r.Context(), id, uid)
	if errors.Is(err, store.ErrNoSuchRequest) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	writeJSON(w, http.StatusOK, thread)
}

func (s *Server) putChatKey(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.chats == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		badRequest(w, "invalid_json")
		return
	}
	var in struct {
		PublicKey string `json:"publicKey"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&in); err != nil {
		badRequest(w, "invalid_json")
		return
	}
	err = s.chats.UpsertChatPublicKey(r.Context(), id, uid, in.PublicKey)
	if errors.Is(err, store.ErrForbidden) {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "forbidden"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) getChatMessages(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.chats == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		badRequest(w, "invalid_json")
		return
	}
	var after *uuid.UUID
	if q := r.URL.Query().Get("after"); q != "" {
		parsed, err := uuid.Parse(q)
		if err == nil {
			after = &parsed
		}
	}
	msgs, err := s.chats.ListChatMessages(r.Context(), id, uid, after)
	if errors.Is(err, store.ErrNoSuchRequest) || errors.Is(err, store.ErrForbidden) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	if msgs == nil {
		msgs = []store.ChatMessageRow{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"messages": msgs})
}

func (s *Server) postChatMessage(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.chats == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		badRequest(w, "invalid_json")
		return
	}
	var in struct {
		Ciphertext string `json:"ciphertext"`
		Nonce      string `json:"nonce"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&in); err != nil {
		badRequest(w, "invalid_json")
		return
	}
	row, err := s.chats.InsertChatMessage(r.Context(), id, uid, in.Ciphertext, in.Nonce)
	if errors.Is(err, store.ErrForbidden) {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "forbidden"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	s.notifyChatMessage(r.Context(), id, uid)
	writeJSON(w, http.StatusCreated, row)
}

func (s *Server) notifyChatMessage(ctx context.Context, threadID, sender uuid.UUID) {
	if s.chats == nil || s.notifications == nil {
		return
	}
	other, err := s.chats.ChatCounterpart(ctx, threadID, sender)
	if err != nil {
		return
	}
	title := "New encrypted message"
	body := "Open KnowMates to read it in your secure chat."
	s.notifyUser(ctx, other, "chat_message", threadID, title, body)
}
