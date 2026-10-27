package api_test

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"

	"knowmates/services/api/internal/store"
)

func markReady(t *testing.T, ctx context.Context, s *store.Store, user uuid.UUID, teach, learn []store.SkillLevel) {
	t.Helper()
	name := "User " + user.String()[:8]
	gender := "male"
	if err := s.UpdateProfile(ctx, user, store.ProfilePatch{DisplayName: &name, Gender: &gender}); err != nil {
		t.Fatal(err)
	}
	if err := s.ReplaceSkills(ctx, user, teach, learn); err != nil {
		t.Fatal(err)
	}
	if err := s.ReplaceAvailability(ctx, user, []store.Slot{{Weekday: 1, StartMin: 540, EndMin: 600}}); err != nil {
		t.Fatal(err)
	}
	if err := s.MarkReady(ctx, user); err != nil {
		t.Fatal(err)
	}
}

func TestSettleIsIdempotent(t *testing.T) {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL not set")
	}
	ctx := context.Background()
	s, err := store.Open(ctx, dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	if err := s.Migrate(ctx); err != nil {
		t.Fatal(err)
	}

	skill := uuid.MustParse("11111111-1111-4111-8111-111111111101")
	learnOther := uuid.MustParse("11111111-1111-4111-8111-111111111104")
	birth := time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC)
	goal := "I want to learn this skill well."
	start := time.Now().UTC().Add(24 * time.Hour).Truncate(time.Minute)
	end := start.Add(time.Hour)

	learnerU, err := s.CreateUser(ctx, fmt.Sprintf("learner.%d@example.com", time.Now().UnixNano()), "hash", birth, "UTC")
	if err != nil {
		t.Fatal(err)
	}
	learner, _ := uuid.Parse(learnerU.ID)
	markReady(t, ctx, s, learner,
		[]store.SkillLevel{{SkillID: learnOther, Proficiency: 1}},
		[]store.SkillLevel{{SkillID: skill, Proficiency: 2}})

	teacherU, err := s.CreateUser(ctx, fmt.Sprintf("teacher.%d@example.com", time.Now().UnixNano()), "hash", birth, "UTC")
	if err != nil {
		t.Fatal(err)
	}
	teacher, _ := uuid.Parse(teacherU.ID)
	markReady(t, ctx, s, teacher, []store.SkillLevel{{SkillID: skill, Proficiency: 4}}, []store.SkillLevel{{SkillID: learnOther, Proficiency: 2}})

	learnerBal, err := s.Balance(ctx, learner)
	if err != nil || learnerBal != 2 {
		t.Fatalf("learner start balance: got %d err %v", learnerBal, err)
	}
	teacherBal, err := s.Balance(ctx, teacher)
	if err != nil || teacherBal != 2 {
		t.Fatalf("teacher start balance: got %d err %v", teacherBal, err)
	}

	req, err := s.CreateRequest(ctx, learner, teacher, skill, goal)
	if err != nil {
		t.Fatal(err)
	}
	if err := s.SetRequestStatus(ctx, req.ID, teacher, "accepted"); err != nil {
		t.Fatal(err)
	}

	sess, err := s.Schedule(ctx, req.ID, learner, start, end, "")
	if err != nil {
		t.Fatal(err)
	}
	learnerBal, err = s.Balance(ctx, learner)
	if err != nil || learnerBal != 1 {
		t.Fatalf("after schedule learner balance: got %d err %v", learnerBal, err)
	}

	st, err := s.Complete(ctx, sess.ID, learner)
	if err != nil || st != "scheduled" {
		t.Fatalf("learner complete: status %q err %v", st, err)
	}
	st, err = s.Complete(ctx, sess.ID, teacher)
	if err != nil || st != "completed" {
		t.Fatalf("teacher complete: status %q err %v", st, err)
	}
	learnerBal, err = s.Balance(ctx, learner)
	if err != nil || learnerBal != 1 {
		t.Fatalf("after settle learner balance: got %d err %v", learnerBal, err)
	}
	teacherBal, err = s.Balance(ctx, teacher)
	if err != nil || teacherBal != 3 {
		t.Fatalf("after settle teacher balance: got %d err %v", teacherBal, err)
	}

	st, err = s.Complete(ctx, sess.ID, learner)
	if err != nil || st != "completed" {
		t.Fatalf("repeat complete: status %q err %v", st, err)
	}
	learnerBal, _ = s.Balance(ctx, learner)
	teacherBal, _ = s.Balance(ctx, teacher)
	if learnerBal != 1 || teacherBal != 3 {
		t.Fatalf("after repeat complete: learner %d teacher %d", learnerBal, teacherBal)
	}
}
