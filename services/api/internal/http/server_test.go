package http

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthz(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rr := httptest.NewRecorder()
	NewServer(nil).Handler().ServeHTTP(rr, req)
	if rr.Code != 200 || rr.Body.String() != "ok" {
		t.Fatalf("got %d %q", rr.Code, rr.Body.String())
	}
}

func TestHealthzPostMethodNotAllowed(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/healthz", nil)
	rr := httptest.NewRecorder()
	NewServer(nil).Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusMethodNotAllowed {
		t.Fatalf("got %d", rr.Code)
	}
}
