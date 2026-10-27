package http

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"knowmates/services/api/internal/store"
)

const validSignUpBody = `{"email":"a@b.co","password":"1234567890","birth_date":"1990-01-01","timezone":"UTC","displayName":"Alex","gender":"male"}`

type fakeUsers struct{ calls int }

func (f *fakeUsers) CreateUser(_ context.Context, email, _ string, _ time.Time, _ string) (store.User, error) {
	f.calls++
	return store.User{ID: "550e8400-e29b-41d4-a716-446655440000", Email: email}, nil
}

type fakeSessions struct{ inserts int }

func (f *fakeSessions) InsertRefresh(_ context.Context, _, _ string, _ time.Time) error {
	f.inserts++
	return nil
}
func (f *fakeSessions) RotateRefresh(context.Context, string, string, time.Time) (string, error) {
	return "", nil
}
func (f *fakeSessions) RevokeRefresh(context.Context, string, string) error { return nil }

type signupProfileStub struct {
	updates int
}

func (signupProfileStub) Me(context.Context, uuid.UUID) (store.Me, error) {
	panic("unused")
}
func (s *signupProfileStub) UpdateProfile(context.Context, uuid.UUID, store.ProfilePatch) error {
	s.updates++
	return nil
}
func (signupProfileStub) ReplaceSkills(context.Context, uuid.UUID, []store.SkillLevel, []store.SkillLevel) error {
	panic("unused")
}
func (signupProfileStub) ReplaceAvailability(context.Context, uuid.UUID, []store.Slot) error {
	panic("unused")
}
func (signupProfileStub) MarkReady(context.Context, uuid.UUID) error { panic("unused") }
func (signupProfileStub) SetAvatarURL(context.Context, uuid.UUID, string) error {
	panic("unused")
}

var testSecret = []byte("0123456789abcdef0123456789abcdef")

func testServer(f *fakeUsers) *Server {
	sess := &fakeSessions{}
	prof := &signupProfileStub{}
	return NewServer(Deps{Users: f, Sessions: sess, Profiles: prof, Secret: testSecret})
}

func signUp(t *testing.T, s *Server, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/sign-up", strings.NewReader(body))
	rr := httptest.NewRecorder()
	s.Handler().ServeHTTP(rr, req)
	return rr
}

func TestSignUpUnderageRejectedBeforeInsert(t *testing.T) {
	f := &fakeUsers{}
	rr := signUp(t, testServer(f), `{"email":"a@b.co","password":"longenoughpw","birth_date":"2015-01-01","timezone":"UTC"}`)
	if rr.Code != 400 || strings.TrimSpace(rr.Body.String()) != `{"error":"underage"}` {
		t.Fatalf("got %d %q", rr.Code, rr.Body.String())
	}
	if f.calls != 0 {
		t.Fatal("insert happened for underage user")
	}
}

func TestSignUpShortPassword(t *testing.T) {
	f := &fakeUsers{}
	rr := signUp(t, testServer(f), `{"email":"a@b.co","password":"123456789","birth_date":"1990-01-01","timezone":"UTC"}`)
	if rr.Code != 400 || f.calls != 0 {
		t.Fatalf("got %d calls=%d", rr.Code, f.calls)
	}
}

func TestSignUpOK(t *testing.T) {
	f := &fakeUsers{}
	s := testServer(f)
	rr := signUp(t, s, validSignUpBody)
	if rr.Code != 201 || f.calls != 1 {
		t.Fatalf("got %d %q calls=%d", rr.Code, rr.Body.String(), f.calls)
	}
	if !strings.Contains(rr.Body.String(), `"access"`) || !strings.Contains(rr.Body.String(), `"refresh"`) {
		t.Fatalf("want token pair, got %q", rr.Body.String())
	}
}
