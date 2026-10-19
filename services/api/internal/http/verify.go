package http

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	"knowmates/services/api/internal/store"
)

const verifyTokenTTL = 24 * time.Hour
const verifyResendCooldown = 10 * time.Minute

// EmailVerifier reads whether the user confirmed their email.
type EmailVerifier interface {
	EmailVerified(ctx context.Context, userID uuid.UUID) (bool, error)
}

// VerifyTokens persists hashed email verification tokens.
type VerifyTokens interface {
	ReplaceEmailToken(ctx context.Context, userID uuid.UUID, tokenHash string, expiresAt time.Time) error
	ConsumeEmailToken(ctx context.Context, tokenHash string) error
}

func newVerifyPlain() (plain, hash string, err error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", "", err
	}
	plain = hex.EncodeToString(b)
	sum := sha256.Sum256([]byte(plain))
	hash = hex.EncodeToString(sum[:])
	return plain, hash, nil
}

func (s *Server) sendVerificationEmail(ctx context.Context, userID uuid.UUID, email string) {
	if s.mail == nil || s.verifyTokens == nil || s.publicHost == "" {
		return
	}
	plain, hash, err := newVerifyPlain()
	if err != nil {
		return
	}
	expires := time.Now().Add(verifyTokenTTL)
	if err := s.verifyTokens.ReplaceEmailToken(ctx, userID, hash, expires); err != nil {
		return
	}
	link := "https://" + s.publicHost + "/v1/auth/verify?token=" + plain
	subject := "Verify your KnowMates email"
	text := "Open this link within 24 hours to verify your email:\n\n" + link + "\n"
	_ = s.mail.Send(ctx, email, subject, text)
}

func (s *Server) getVerify(w http.ResponseWriter, r *http.Request) {
	if s.verifyTokens == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	plain := r.URL.Query().Get("token")
	if plain == "" {
		badRequest(w, "bad_token")
		return
	}
	sum := sha256.Sum256([]byte(plain))
	hash := hex.EncodeToString(sum[:])
	err := s.verifyTokens.ConsumeEmailToken(r.Context(), hash)
	if errors.Is(err, store.ErrBadVerifyToken) {
		badRequest(w, "bad_token")
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) postVerifyResend(w http.ResponseWriter, r *http.Request) {
	uid, ok := UserIDFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if s.emailVerified == nil || s.verifyTokens == nil || s.mail == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	okVerified, err := s.emailVerified.EmailVerified(r.Context(), uid)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	if okVerified {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	key := "verify:" + uid.String()
	if s.redis != nil {
		if err := s.redis.Get(r.Context(), key).Err(); err == nil {
			writeJSON(w, http.StatusTooManyRequests, map[string]string{"error": "rate_limited"})
			return
		} else if !errors.Is(err, redis.Nil) {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
			return
		}
	}
	if s.userEmail == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "unavailable"})
		return
	}
	email, err := s.userEmail.UserEmail(r.Context(), uid)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	plain, hash, err := newVerifyPlain()
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	expires := time.Now().Add(verifyTokenTTL)
	if err := s.verifyTokens.ReplaceEmailToken(r.Context(), uid, hash, expires); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	link := "https://" + s.publicHost + "/v1/auth/verify?token=" + plain
	subject := "Verify your KnowMates email"
	text := "Open this link within 24 hours to verify your email:\n\n" + link + "\n"
	if err := s.mail.Send(r.Context(), email, subject, text); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	if s.redis != nil {
		_ = s.redis.Set(r.Context(), key, "1", verifyResendCooldown).Err()
	}
	w.WriteHeader(http.StatusNoContent)
}

// UserEmail loads the account email for verification resend.
type UserEmail interface {
	UserEmail(ctx context.Context, userID uuid.UUID) (string, error)
}
