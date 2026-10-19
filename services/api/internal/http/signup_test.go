package http

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"knowmates/services/api/internal/store"
)

type fakeUsers struct{ calls int }

func (f *fakeUsers) CreateUser(_ context.Context, email, _ string, _ time.Time, _ string) (store.User, error) {
	f.calls++
	return store.User{ID: "u1", Email: email}, nil
}

func signUp(t *testing.T, f *fakeUsers, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/signup", strings.NewReader(body))
	rr := httptest.NewRecorder()
	NewServer(f).Handler().ServeHTTP(rr, req)
	return rr
}

func TestSignUpUnderageRejectedBeforeInsert(t *testing.T) {
	f := &fakeUsers{}
	rr := signUp(t, f, `{"email":"a@b.co","password":"longenoughpw","birth_date":"2015-01-01","timezone":"UTC"}`)
	if rr.Code != 400 || strings.TrimSpace(rr.Body.String()) != `{"error":"underage"}` {
		t.Fatalf("got %d %q", rr.Code, rr.Body.String())
	}
	if f.calls != 0 {
		t.Fatal("insert happened for underage user")
	}
}

func TestSignUpShortPassword(t *testing.T) {
	f := &fakeUsers{}
	rr := signUp(t, f, `{"email":"a@b.co","password":"123456789","birth_date":"1990-01-01","timezone":"UTC"}`)
	if rr.Code != 400 || f.calls != 0 {
		t.Fatalf("got %d calls=%d", rr.Code, f.calls)
	}
}

func TestSignUpOK(t *testing.T) {
	f := &fakeUsers{}
	rr := signUp(t, f, `{"email":"a@b.co","password":"1234567890","birth_date":"1990-01-01","timezone":"UTC"}`)
	if rr.Code != 201 || f.calls != 1 {
		t.Fatalf("got %d %q calls=%d", rr.Code, rr.Body.String(), f.calls)
	}
}
