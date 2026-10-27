package avatar

import (
	"bytes"
	"image/jpeg"
	"testing"

	"github.com/google/uuid"
)

func TestGeneratePortraitJPEGUniquePerUser(t *testing.T) {
	a := uuid.MustParse("11111111-1111-4111-8111-111111111101")
	b := uuid.MustParse("22222222-2222-4222-8222-222222222222")
	ja, err := GeneratePortraitJPEG(a, "male")
	if err != nil {
		t.Fatal(err)
	}
	jb, err := GeneratePortraitJPEG(b, "female")
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Equal(ja, jb) {
		t.Fatal("expected different avatars for different users")
	}
	if _, err := jpeg.Decode(bytes.NewReader(ja)); err != nil {
		t.Fatalf("invalid jpeg: %v", err)
	}
}
