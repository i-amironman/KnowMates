package store

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"
)

func TestCreateUser(t *testing.T) {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL not set")
	}
	ctx := context.Background()
	s, err := Open(ctx, dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	if err := s.Migrate(ctx); err != nil {
		t.Fatal(err)
	}
	if err := s.Migrate(ctx); err != nil {
		t.Fatalf("second migrate not idempotent: %v", err)
	}

	email := fmt.Sprintf("Test.%d@Example.com", time.Now().UnixNano())
	birth := time.Date(1990, 5, 1, 0, 0, 0, 0, time.UTC)
	u, err := s.CreateUser(ctx, email, "hash", birth, "Asia/Kolkata")
	if err != nil {
		t.Fatal(err)
	}
	if u.ID == "" || !strings.EqualFold(u.Email, email) {
		t.Fatalf("bad user %+v", u)
	}
	var got string
	if err := s.pool.QueryRow(ctx, `SELECT email::text FROM users WHERE email = $1`, strings.ToLower(email)).Scan(&got); err != nil {
		t.Fatalf("citext lookup by lowercase failed: %v", err)
	}
	if _, err := s.CreateUser(ctx, strings.ToLower(email), "hash", birth, "UTC"); err != ErrEmailTaken {
		t.Fatalf("want ErrEmailTaken, got %v", err)
	}
}
