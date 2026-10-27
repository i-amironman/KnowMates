package store

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"

	"knowmates/services/api/internal/auth"
)

func TestBlockedTeacherHidden(t *testing.T) {
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

	skill := uuid.MustParse("11111111-1111-4111-8111-111111111101")
	learnOther := uuid.MustParse("11111111-1111-4111-8111-111111111104")
	slot := []Slot{{Weekday: 1, StartMin: 540, EndMin: 600}}
	birth := time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC)

	viewerU, err := s.CreateUser(ctx, fmt.Sprintf("block.viewer.%d@example.com", time.Now().UnixNano()), "hash", birth, "UTC")
	if err != nil {
		t.Fatal(err)
	}
	viewer, _ := uuid.Parse(viewerU.ID)
	if err := s.UpdateProfile(ctx, viewer, ProfilePatch{DisplayName: strPtr("Viewer"), Languages: []string{"en"}, Gender: strPtr("female")}); err != nil {
		t.Fatal(err)
	}
	if err := s.ReplaceSkills(ctx, viewer, []SkillLevel{{SkillID: learnOther, Proficiency: 3}}, []SkillLevel{{SkillID: skill, Proficiency: 2}}); err != nil {
		t.Fatal(err)
	}
	if err := s.ReplaceAvailability(ctx, viewer, slot); err != nil {
		t.Fatal(err)
	}
	if err := s.MarkReady(ctx, viewer); err != nil {
		t.Fatal(err)
	}

	teacherU, err := s.CreateUser(ctx, fmt.Sprintf("block.teacher.%d@example.com", time.Now().UnixNano()), "hash", birth, "UTC")
	if err != nil {
		t.Fatal(err)
	}
	teacher, _ := uuid.Parse(teacherU.ID)
	name := "Teacher"
	if err := s.UpdateProfile(ctx, teacher, ProfilePatch{DisplayName: &name, Languages: []string{"en"}, Gender: strPtr("male")}); err != nil {
		t.Fatal(err)
	}
	if err := s.ReplaceSkills(ctx, teacher, []SkillLevel{{SkillID: skill, Proficiency: 4}}, []SkillLevel{{SkillID: learnOther, Proficiency: 2}}); err != nil {
		t.Fatal(err)
	}
	if err := s.ReplaceAvailability(ctx, teacher, slot); err != nil {
		t.Fatal(err)
	}
	if err := s.MarkReady(ctx, teacher); err != nil {
		t.Fatal(err)
	}

	before, err := s.Discover(ctx, viewer, DiscoverFilter{SkillID: skill}, nil)
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, p := range before.People {
		if p.ID == teacher {
			found = true
			break
		}
	}
	if !found {
		t.Fatal("teacher should appear before block")
	}

	if err := s.BlockUser(ctx, viewer, teacher); err != nil {
		t.Fatal(err)
	}
	after, err := s.Discover(ctx, viewer, DiscoverFilter{SkillID: skill}, nil)
	if err != nil {
		t.Fatal(err)
	}
	for _, p := range after.People {
		if p.ID == teacher {
			t.Fatal("blocked teacher still in discover")
		}
	}
}

func TestDeleteRevokesLogin(t *testing.T) {
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

	email := fmt.Sprintf("delete.me.%d@example.com", time.Now().UnixNano())
	hash, err := auth.Hash("longpassword123")
	if err != nil {
		t.Fatal(err)
	}
	birth := time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC)
	u, err := s.CreateUser(ctx, email, hash, birth, "UTC")
	if err != nil {
		t.Fatal(err)
	}
	uid, _ := uuid.Parse(u.ID)

	if err := s.DeleteUser(ctx, uid); err != nil {
		t.Fatal(err)
	}
	_, _, err = s.UserCredsByEmail(ctx, email)
	if err != ErrNoSuchUser {
		t.Fatalf("sign-in after delete: want ErrNoSuchUser, got %v", err)
	}
}
