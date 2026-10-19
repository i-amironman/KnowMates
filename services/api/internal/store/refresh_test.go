package store

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"
)

func TestRotateRefreshTheftRevokesOtherActive(t *testing.T) {
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

	email := fmt.Sprintf("refresh-theft-%d@example.com", time.Now().UnixNano())
	u, err := s.CreateUser(ctx, email, "hash", time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC), "UTC")
	if err != nil {
		t.Fatal(err)
	}
	exp := time.Now().Add(refreshTTL)
	hashA, hashB := "aa"+email, "bb"+email
	if err := s.InsertRefresh(ctx, u.ID, hashA, exp); err != nil {
		t.Fatal(err)
	}
	if err := s.InsertRefresh(ctx, u.ID, hashB, exp); err != nil {
		t.Fatal(err)
	}

	if _, err := s.RotateRefresh(ctx, hashA, "cc"+email, exp); err != nil {
		t.Fatalf("first rotate: %v", err)
	}
	if _, err := s.RotateRefresh(ctx, hashA, "dd"+email, exp); err != ErrRefreshRevoked {
		t.Fatalf("reuse revoked: got %v want ErrRefreshRevoked", err)
	}

	var active int
	err = s.pool.QueryRow(ctx,
		`SELECT count(*) FROM refresh_tokens WHERE user_id = $1 AND revoked_at IS NULL`, u.ID).
		Scan(&active)
	if err != nil {
		t.Fatal(err)
	}
	if active != 0 {
		t.Fatalf("theft response left %d active refresh(es), want 0", active)
	}
}
