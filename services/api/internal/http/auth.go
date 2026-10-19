package http

import (
	"context"
	"encoding/json"
	"errors"
	"net"
	"net/http"
	"net/mail"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	"knowmates/services/api/internal/auth"
	"knowmates/services/api/internal/store"
)

type ctxKey int

const userIDKey ctxKey = 1

const refreshTTL = 30 * 24 * time.Hour

// Sessions covers refresh-token persistence the auth handlers need.
type Sessions interface {
	InsertRefresh(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error
	RotateRefresh(ctx context.Context, tokenHash, newHash string, newExpires time.Time) (userID string, err error)
	RevokeRefresh(ctx context.Context, userID, tokenHash string) error
}

// SignInUsers loads credentials for sign-in.
type SignInUsers interface {
	UserCredsByEmail(ctx context.Context, email string) (id, passwordHash string, err error)
}

type tokenPair struct {
	Access  string `json:"access"`
	Refresh string `json:"refresh"`
}

func (s *Server) issuePairCtx(ctx context.Context, userID string, now time.Time) (tokenPair, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return tokenPair{}, err
	}
	access, err := auth.IssueAccess(s.authSecret, uid, now)
	if err != nil {
		return tokenPair{}, err
	}
	plain, hash := auth.NewRefresh()
	expires := now.Add(refreshTTL)
	if s.sessions == nil {
		return tokenPair{}, errors.New("sessions unavailable")
	}
	if err := s.sessions.InsertRefresh(ctx, userID, hash, expires); err != nil {
		return tokenPair{}, err
	}
	return tokenPair{Access: access, Refresh: plain}, nil
}

func clientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		if i := strings.IndexByte(xff, ','); i >= 0 {
			xff = strings.TrimSpace(xff[:i])
		}
		return xff
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func (s *Server) loginAllowed(ctx context.Context, ip string) (bool, error) {
	if s.redis == nil {
		return true, nil
	}
	key := "login:" + ip
	n, err := s.redis.Incr(ctx, key).Result()
	if err != nil {
		return false, err
	}
	if n == 1 {
		_ = s.redis.Expire(ctx, key, 60*time.Second).Err()
	}
	return n <= 10, nil
}

func (s *Server) signIn(w http.ResponseWriter, r *http.Request) {
	ok, err := s.loginAllowed(r.Context(), clientIP(r))
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	if !ok {
		writeJSON(w, http.StatusTooManyRequests, map[string]string{"error": "rate_limited"})
		return
	}
	var in struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&in); err != nil {
		badRequest(w, "invalid_json")
		return
	}
	email := strings.ToLower(strings.TrimSpace(in.Email))
	if _, err := mail.ParseAddress(email); err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "bad_credentials"})
		return
	}
	if s.creds == nil || s.sessions == nil || len(s.authSecret) < 32 {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	id, hash, err := s.creds.UserCredsByEmail(r.Context(), email)
	if errors.Is(err, store.ErrNoSuchUser) {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "bad_credentials"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	okPass, err := auth.Verify(hash, in.Password)
	if err != nil || !okPass {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "bad_credentials"})
		return
	}
	pair, err := s.issuePairCtx(r.Context(), id, time.Now())
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	writeJSON(w, http.StatusOK, pair)
}

func (s *Server) refresh(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Refresh string `json:"refresh"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&in); err != nil || in.Refresh == "" {
		badRequest(w, "invalid_json")
		return
	}
	if s.sessions == nil || len(s.authSecret) < 32 {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	now := time.Now()
	hash := auth.HashRefresh(in.Refresh)
	newPlain, newHash := auth.NewRefresh()
	uid, err := s.sessions.RotateRefresh(r.Context(), hash, newHash, now.Add(refreshTTL))
	switch {
	case errors.Is(err, store.ErrRefreshRevoked), errors.Is(err, store.ErrNoSuchRefresh), errors.Is(err, store.ErrRefreshExpired):
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "bad_credentials"})
	case err != nil:
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
	default:
		userUUID, _ := uuid.Parse(uid)
		access, err := auth.IssueAccess(s.authSecret, userUUID, now)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
			return
		}
		writeJSON(w, http.StatusOK, tokenPair{Access: access, Refresh: newPlain})
	}
}

func (s *Server) signOut(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Refresh string `json:"refresh"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&in); err != nil || in.Refresh == "" {
		badRequest(w, "invalid_json")
		return
	}
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.sessions == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	err := s.sessions.RevokeRefresh(r.Context(), uid.String(), auth.HashRefresh(in.Refresh))
	if errors.Is(err, store.ErrNoSuchRefresh) {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "bad_credentials"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// UserIDFromContext returns the authenticated user id set by WithUser.
func UserIDFromContext(ctx context.Context) (uuid.UUID, bool) {
	id, ok := ctx.Value(userIDKey).(uuid.UUID)
	return id, ok
}

// WithUser requires a valid Bearer access token and puts the user id in context.
func (s *Server) WithUser(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if len(s.authSecret) < 32 {
			writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
			return
		}
		h := r.Header.Get("Authorization")
		if !strings.HasPrefix(h, "Bearer ") {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
			return
		}
		raw := strings.TrimSpace(h[len("Bearer "):])
		id, err := auth.ParseAccess(s.authSecret, raw, time.Now())
		if err != nil {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), userIDKey, id)))
	}
}

// RedisClient is the subset of go-redis used for rate limits and discover cache.
type RedisClient interface {
	Incr(ctx context.Context, key string) *redis.IntCmd
	Expire(ctx context.Context, key string, expiration time.Duration) *redis.BoolCmd
	Get(ctx context.Context, key string) *redis.StringCmd
	Set(ctx context.Context, key string, value interface{}, expiration time.Duration) *redis.StatusCmd
}
