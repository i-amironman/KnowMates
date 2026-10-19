package store

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestStarterGrantOnce(t *testing.T) {
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

	email := fmt.Sprintf("grant.%d@example.com", time.Now().UnixNano())
	u, err := s.CreateUser(ctx, email, "hash", time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC), "UTC")
	if err != nil {
		t.Fatal(err)
	}
	uid, err := uuid.Parse(u.ID)
	if err != nil {
		t.Fatal(err)
	}
	if err := s.UpdateProfile(ctx, uid, ProfilePatch{
		DisplayName: strPtr("Alex"),
	}); err != nil {
		t.Fatal(err)
	}
	teach := uuid.MustParse("11111111-1111-4111-8111-111111111101")
	learn := uuid.MustParse("11111111-1111-4111-8111-111111111104")
	if err := s.ReplaceSkills(ctx, uid, []SkillLevel{{SkillID: teach, Proficiency: 4}}, []SkillLevel{{SkillID: learn, Proficiency: 2}}); err != nil {
		t.Fatal(err)
	}
	if err := s.ReplaceAvailability(ctx, uid, []Slot{{Weekday: 1, StartMin: 540, EndMin: 600}}); err != nil {
		t.Fatal(err)
	}
	if err := s.MarkReady(ctx, uid); err != nil {
		t.Fatal(err)
	}
	if err := s.MarkReady(ctx, uid); err != nil {
		t.Fatal(err)
	}
	bal, err := s.Balance(ctx, uid)
	if err != nil {
		t.Fatal(err)
	}
	if bal != 2 {
		t.Fatalf("balance %d", bal)
	}
}

func strPtr(s string) *string { return &s }
