package http

import (
	"context"
	"net/http"

	"knowmates/services/api/internal/store"
)

// SkillsCatalog lists seeded skills for profile setup.
type SkillsCatalog interface {
	ListSkills(ctx context.Context, q string) ([]store.CatalogSkill, error)
}

func (s *Server) getSkills(w http.ResponseWriter, r *http.Request) {
	if _, ok := UserIDFromContext(r.Context()); !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.skills == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	list, err := s.skills.ListSkills(r.Context(), r.URL.Query().Get("q"))
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	if list == nil {
		list = []store.CatalogSkill{}
	}
	writeJSON(w, http.StatusOK, list)
}
