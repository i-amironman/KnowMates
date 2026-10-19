package http

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
)

type recordingMail struct {
	mu    sync.Mutex
	sends int
}

func (r *recordingMail) Send(_ context.Context, _, _, _ string) error {
	r.mu.Lock()
	r.sends++
	r.mu.Unlock()
	return nil
}

type fakeVerifyTokens struct{}

func (fakeVerifyTokens) ReplaceEmailToken(_ context.Context, _ uuid.UUID, _ string, _ time.Time) error {
	return nil
}
func (fakeVerifyTokens) ConsumeEmailToken(_ context.Context, _ string) error { return nil }

func TestSignUpSendsVerificationEmail(t *testing.T) {
	f := &fakeUsers{}
	m := &recordingMail{}
	s := NewServer(Deps{
		Users:        f,
		Sessions:     &fakeSessions{},
		Secret:       testSecret,
		Mail:         m,
		VerifyTokens: fakeVerifyTokens{},
		PublicHost:   "api.example.com",
	})
	rr := signUp(t, s, `{"email":"a@b.co","password":"1234567890","birth_date":"1990-01-01","timezone":"UTC"}`)
	if rr.Code != 201 {
		t.Fatalf("got %d %q", rr.Code, rr.Body.String())
	}
	m.mu.Lock()
	n := m.sends
	m.mu.Unlock()
	if n != 1 {
		t.Fatalf("Send calls = %d", n)
	}
}
