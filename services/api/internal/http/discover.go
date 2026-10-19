package http

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	"knowmates/services/api/internal/store"
)

const discoverCacheTTL = 30 * time.Second

// DiscoverStore loads ranked learning partners.
type DiscoverStore interface {
	Discover(ctx context.Context, viewerID uuid.UUID, f store.DiscoverFilter, cursor *store.DiscoverCursor) (store.DiscoverResult, error)
}

// DiscoverRedis caches discover JSON.
type DiscoverRedis interface {
	Get(ctx context.Context, key string) *redis.StringCmd
	Set(ctx context.Context, key string, value interface{}, expiration time.Duration) *redis.StatusCmd
}

func (s *Server) getDiscover(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.discover == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	skillRaw := r.URL.Query().Get("skillId")
	skillID, err := uuid.Parse(skillRaw)
	if err != nil {
		badRequest(w, "bad_skill")
		return
	}
	f := store.DiscoverFilter{
		SkillID:  skillID,
		Language: r.URL.Query().Get("language"),
	}
	if wd := r.URL.Query().Get("weekday"); wd != "" {
		n, err := strconv.Atoi(wd)
		if err != nil || n < 0 || n > 6 {
			badRequest(w, "bad_weekday")
			return
		}
		f.Weekday = &n
	}
	cursorRaw := r.URL.Query().Get("cursor")
	var cursor *store.DiscoverCursor
	if cursorRaw != "" {
		cursor, err = store.DecodeDiscoverCursor(cursorRaw)
		if err != nil {
			badRequest(w, "bad_cursor")
			return
		}
	}

	cacheKey := discoverCacheKey(uid, f)
	if cursor == nil && s.discoverRedis != nil {
		if cached, err := s.discoverRedis.Get(r.Context(), cacheKey).Bytes(); err == nil {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write(cached)
			return
		}
	}

	out, err := s.discover.Discover(r.Context(), uid, f, cursor)
	if errors.Is(err, store.ErrNoSuchUser) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}

	if cursor == nil && s.discoverRedis != nil {
		if b, err := json.Marshal(out); err == nil {
			_ = s.discoverRedis.Set(r.Context(), cacheKey, b, discoverCacheTTL).Err()
		}
	}
	writeJSON(w, http.StatusOK, out)
}

func discoverCacheKey(viewer uuid.UUID, f store.DiscoverFilter) string {
	wd := ""
	if f.Weekday != nil {
		wd = strconv.Itoa(*f.Weekday)
	}
	return "disc:" + viewer.String() + ":" + f.SkillID.String() + ":" + f.Language + ":" + wd
}
