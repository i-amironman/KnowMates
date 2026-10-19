package auth

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestAccessRoundTrip(t *testing.T) {
	id := uuid.New()
	raw, err := IssueAccess([]byte("0123456789abcdef0123456789abcdef"), id, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	got, err := ParseAccess([]byte("0123456789abcdef0123456789abcdef"), raw, time.Now())
	if err != nil || got != id {
		t.Fatalf("got %v %v", got, err)
	}
}
