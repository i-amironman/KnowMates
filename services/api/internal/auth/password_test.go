package auth

import "testing"

func TestHashRoundTrip(t *testing.T) {
	h, err := Hash("correct horse battery")
	if err != nil {
		t.Fatal(err)
	}
	ok, err := Verify(h, "correct horse battery")
	if err != nil || !ok {
		t.Fatalf("verify failed %v %v", ok, err)
	}
	ok, err = Verify(h, "wrong password")
	if err != nil || ok {
		t.Fatalf("wrong password accepted %v %v", ok, err)
	}
	if _, err := Verify("not-a-hash", "x"); err == nil {
		t.Fatal("expected error for malformed hash")
	}
}
