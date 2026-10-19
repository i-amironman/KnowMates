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

type fakeSkills struct {
	q    string
	list []store.CatalogSkill
}

func (f *fakeSkills) ListSkills(_ context.Context, q string) ([]store.CatalogSkill, error) {
	f.q = q
	return f.list, nil
}

func TestGetSkillsUnauthorized(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/v1/skills", nil)
	rr := httptest.NewRecorder()
	NewServer(Deps{Skills: &fakeSkills{}, Secret: testSecret}).Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("got %d", rr.Code)
	}
}

func TestGetSkillsReturnsCatalog(t *testing.T) {
	id := uuid.MustParse("11111111-1111-4111-8111-111111111101")
	fake := &fakeSkills{
		list: []store.CatalogSkill{{ID: id, Slug: "web-development", Name: "Web Development"}},
	}
	s := NewServer(Deps{Skills: fake, Secret: testSecret})
	uid := uuid.MustParse("550e8400-e29b-41d4-a716-446655440000")
	token, err := auth.IssueAccess(testSecret, uid, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest(http.MethodGet, "/v1/skills?q=web", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rr := httptest.NewRecorder()
	s.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("got %d %q", rr.Code, rr.Body.String())
	}
	if fake.q != "web" {
		t.Fatalf("query %q", fake.q)
	}
	if !strings.Contains(rr.Body.String(), "Web Development") {
		t.Fatalf("body %q", rr.Body.String())
	}
}
