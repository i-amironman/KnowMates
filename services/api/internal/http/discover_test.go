package http

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"knowmates/services/api/internal/auth"
	"knowmates/services/api/internal/store"
)

type fakeDiscover struct{ called bool }

func (f *fakeDiscover) Discover(_ context.Context, _ uuid.UUID, _ store.DiscoverFilter, _ *store.DiscoverCursor) (store.DiscoverResult, error) {
	f.called = true
	return store.DiscoverResult{}, nil
}

type fakeEmailVerifier struct{ verified bool }

func (f *fakeEmailVerifier) EmailVerified(_ context.Context, _ uuid.UUID) (bool, error) {
	return f.verified, nil
}

func TestDiscoverRequiresVerifiedEmail(t *testing.T) {
	disc := &fakeDiscover{}
	ev := &fakeEmailVerifier{verified: false}
	s := NewServer(Deps{
		Discover:      disc,
		EmailVerified: ev,
		Secret:        testSecret,
	})
	uid := uuid.MustParse("550e8400-e29b-41d4-a716-446655440000")
	token, err := auth.IssueAccess(testSecret, uid, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	skillID := "11111111-1111-4111-8111-111111111101"
	req := httptest.NewRequest(http.MethodGet, "/v1/discover?skillId="+skillID, nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rr := httptest.NewRecorder()
	s.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusForbidden {
		t.Fatalf("got %d %q", rr.Code, rr.Body.String())
	}
	if strings.TrimSpace(rr.Body.String()) != `{"error":"email_unverified"}` {
		t.Fatalf("body %q", rr.Body.String())
	}
	if disc.called {
		t.Fatal("discover store called for unverified user")
	}
}
