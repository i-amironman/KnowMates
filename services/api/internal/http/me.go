package http

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"

	"knowmates/services/api/internal/store"
)

// ProfileStore covers authenticated profile routes.
type ProfileStore interface {
	Me(ctx context.Context, userID uuid.UUID) (store.Me, error)
	UpdateProfile(ctx context.Context, userID uuid.UUID, p store.ProfilePatch) error
	ReplaceSkills(ctx context.Context, userID uuid.UUID, teach, learn []store.SkillLevel) error
	ReplaceAvailability(ctx context.Context, userID uuid.UUID, slots []store.Slot) error
	MarkReady(ctx context.Context, userID uuid.UUID) error
	SetAvatarURL(ctx context.Context, userID uuid.UUID, url string) error
}

func (s *Server) getMe(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.profiles == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	m, err := s.profiles.Me(r.Context(), uid)
	if errors.Is(err, store.ErrNoSuchUser) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	writeJSON(w, http.StatusOK, m)
}

func (s *Server) patchMe(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.profiles == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	var in struct {
		DisplayName *string  `json:"displayName"`
		Bio         *string  `json:"bio"`
		Languages   []string `json:"languages"`
		Timezone    *string  `json:"timezone"`
		Gender      *string  `json:"gender"`
		Ready       *bool    `json:"ready"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&in); err != nil {
		badRequest(w, "invalid_json")
		return
	}
	if in.Timezone != nil {
		if _, err := time.LoadLocation(*in.Timezone); err != nil {
			badRequest(w, "invalid_timezone")
			return
		}
	}
	patch := store.ProfilePatch{
		DisplayName: in.DisplayName,
		Bio:         in.Bio,
		Languages:   in.Languages,
		Timezone:    in.Timezone,
		Gender:      in.Gender,
	}
	if err := s.profiles.UpdateProfile(r.Context(), uid, patch); err != nil {
		if errors.Is(err, store.ErrInvalidGender) {
			badRequest(w, "invalid_gender")
			return
		}
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	if in.Ready != nil && *in.Ready {
		if err := s.profiles.MarkReady(r.Context(), uid); err != nil {
			if errors.Is(err, store.ErrProfileIncomplete) {
				badRequest(w, "profile_incomplete")
				return
			}
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
			return
		}
	}
	s.getMe(w, r)
}

func (s *Server) putSkills(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.profiles == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	var in struct {
		Teach []struct {
			SkillID     uuid.UUID `json:"skillId"`
			Proficiency int       `json:"proficiency"`
		} `json:"teach"`
		Learn []struct {
			SkillID     uuid.UUID `json:"skillId"`
			Proficiency int       `json:"proficiency"`
		} `json:"learn"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&in); err != nil {
		badRequest(w, "invalid_json")
		return
	}
	teach := make([]store.SkillLevel, len(in.Teach))
	for i, t := range in.Teach {
		teach[i] = store.SkillLevel{SkillID: t.SkillID, Proficiency: t.Proficiency}
	}
	learn := make([]store.SkillLevel, len(in.Learn))
	for i, t := range in.Learn {
		learn[i] = store.SkillLevel{SkillID: t.SkillID, Proficiency: t.Proficiency}
	}
	if err := s.profiles.ReplaceSkills(r.Context(), uid, teach, learn); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) putAvailability(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.profiles == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	var in struct {
		Slots []store.Slot `json:"slots"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&in); err != nil {
		badRequest(w, "invalid_json")
		return
	}
	if err := s.profiles.ReplaceAvailability(r.Context(), uid, in.Slots); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) postAvatar(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.profiles == nil || s.avatars == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	ct := r.Header.Get("Content-Type")
	if !strings.HasPrefix(ct, "image/jpeg") {
		badRequest(w, "invalid_content_type")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 1<<20))
	if err != nil {
		badRequest(w, "body_too_large")
		return
	}
	url, err := s.avatars.PutJPEG(r.Context(), uid, body)
	if err != nil {
		badRequest(w, "invalid_image")
		return
	}
	if err := s.profiles.SetAvatarURL(r.Context(), uid, url); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"avatarUrl": url})
}
