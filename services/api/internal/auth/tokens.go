package auth

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
)

const accessTTL = 15 * time.Minute

var (
	ErrBadToken   = errors.New("auth: invalid token")
	ErrExpired    = errors.New("auth: token expired")
	ErrShortSecret = errors.New("auth: secret too short")
)

// IssueAccess returns an HMAC-SHA256 JWT with sub and exp (15m TTL).
func IssueAccess(secret []byte, userID uuid.UUID, now time.Time) (string, error) {
	if len(secret) < 32 {
		return "", ErrShortSecret
	}
	header := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"HS256","typ":"JWT"}`))
	payload, err := json.Marshal(map[string]any{
		"sub": userID.String(),
		"exp": now.Add(accessTTL).Unix(),
	})
	if err != nil {
		return "", err
	}
	body := header + "." + base64.RawURLEncoding.EncodeToString(payload)
	sig := hmacSHA256(secret, body)
	return body + "." + base64.RawURLEncoding.EncodeToString(sig), nil
}

// ParseAccess validates the JWT and returns the subject user id.
func ParseAccess(secret []byte, raw string, now time.Time) (uuid.UUID, error) {
	if len(secret) < 32 {
		return uuid.Nil, ErrShortSecret
	}
	parts := strings.Split(raw, ".")
	if len(parts) != 3 {
		return uuid.Nil, ErrBadToken
	}
	body := parts[0] + "." + parts[1]
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil || !hmac.Equal(sig, hmacSHA256(secret, body)) {
		return uuid.Nil, ErrBadToken
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return uuid.Nil, ErrBadToken
	}
	var claims struct {
		Sub string `json:"sub"`
		Exp int64  `json:"exp"`
	}
	if err := json.Unmarshal(payload, &claims); err != nil || claims.Sub == "" {
		return uuid.Nil, ErrBadToken
	}
	if claims.Exp <= now.Unix() {
		return uuid.Nil, ErrExpired
	}
	id, err := uuid.Parse(claims.Sub)
	if err != nil {
		return uuid.Nil, ErrBadToken
	}
	return id, nil
}

// NewRefresh returns a 32-byte random hex plain token and its SHA-256 hex hash for storage.
func NewRefresh() (plain string, hash string) {
	b := make([]byte, 32)
	_, _ = rand.Read(b)
	plain = hex.EncodeToString(b)
	sum := sha256.Sum256([]byte(plain))
	hash = hex.EncodeToString(sum[:])
	return plain, hash
}

// HashRefresh returns the SHA-256 hex digest of a refresh plain token.
func HashRefresh(plain string) string {
	sum := sha256.Sum256([]byte(plain))
	return hex.EncodeToString(sum[:])
}

func hmacSHA256(secret []byte, msg string) []byte {
	m := hmac.New(sha256.New, secret)
	_, _ = m.Write([]byte(msg))
	return m.Sum(nil)
}
