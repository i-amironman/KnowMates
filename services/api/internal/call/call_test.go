package call

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"strconv"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestCanJoinWindow(t *testing.T) {
	start := time.Date(2026, 10, 19, 12, 0, 0, 0, time.UTC)
	if CanJoin(start.Add(-11*time.Minute), "scheduled", start) {
		t.Fatal("11 minutes early")
	}
	if !CanJoin(start.Add(-9*time.Minute), "scheduled", start) {
		t.Fatal("9 minutes early should open")
	}
	if !CanJoin(start.Add(2*time.Hour), "scheduled", start) {
		t.Fatal("past ends_at stays open while scheduled")
	}
	for _, status := range []string{"cancelled", "completed", "disputed"} {
		if CanJoin(start, status, start) {
			t.Fatal(status)
		}
	}
}

func TestTurnCredsMatchCoturnREST(t *testing.T) {
	id := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	now := time.Unix(1_700_000_000, 0).UTC()
	user, pass, exp := TurnCreds("test-secret", id, now)
	if exp.Sub(now) != time.Hour {
		t.Fatalf("ttl %s", exp.Sub(now))
	}
	if user != strconv.FormatInt(exp.Unix(), 10)+":"+id.String() {
		t.Fatalf("username %s", user)
	}
	mac := hmac.New(sha1.New, []byte("test-secret"))
	mac.Write([]byte(user))
	want := base64.StdEncoding.EncodeToString(mac.Sum(nil))
	if pass != want {
		t.Fatalf("password %s", pass)
	}
}
