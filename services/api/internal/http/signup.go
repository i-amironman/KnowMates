package http

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/mail"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"

	"knowmates/services/api/internal/auth"
	"knowmates/services/api/internal/store"
)

const minPasswordLen = 10

// Users is the slice of the store the sign-up handler needs.
type Users interface {
	CreateUser(ctx context.Context, email, hash string, birth time.Time, timezone string) (store.User, error)
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func badRequest(w http.ResponseWriter, msg string) {
	writeJSON(w, http.StatusBadRequest, map[string]string{"error": msg})
}

func (s *Server) signUp(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Email     string `json:"email"`
		Password  string `json:"password"`
		BirthDate string `json:"birth_date"`
		Timezone  string `json:"timezone"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&in); err != nil {
		badRequest(w, "invalid_json")
		return
	}
	email := strings.ToLower(strings.TrimSpace(in.Email))
	if _, err := mail.ParseAddress(email); err != nil {
		badRequest(w, "invalid_email")
		return
	}
	if utf8.RuneCountInString(in.Password) < minPasswordLen {
		badRequest(w, "password_too_short")
		return
	}
	if in.Timezone == "" {
		badRequest(w, "invalid_timezone")
		return
	}
	if _, err := time.LoadLocation(in.Timezone); err != nil {
		badRequest(w, "invalid_timezone")
		return
	}
	birth, err := time.Parse("2006-01-02", in.BirthDate)
	if err != nil {
		badRequest(w, "invalid_birth_date")
		return
	}
	if store.AgeYears(birth, time.Now().UTC()) < 18 {
		badRequest(w, "underage")
		return
	}
	if s.users == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	hash, err := auth.Hash(in.Password)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	u, err := s.users.CreateUser(r.Context(), email, hash, birth, in.Timezone)
	switch {
	case errors.Is(err, store.ErrEmailTaken):
		writeJSON(w, http.StatusConflict, map[string]string{"error": "email_taken"})
	case err != nil:
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
	default:
		if len(s.authSecret) < 32 || s.sessions == nil {
			writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
			return
		}
		pair, err := s.issuePairCtx(r.Context(), u.ID, time.Now())
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
			return
		}
		if uid, parseErr := uuid.Parse(u.ID); parseErr == nil {
			s.sendVerificationEmail(r.Context(), uid, email)
		}
		writeJSON(w, http.StatusCreated, pair)
	}
}
