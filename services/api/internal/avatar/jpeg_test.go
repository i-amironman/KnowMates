package avatar

import (
	"bytes"
	"image"
	"image/color"
	"image/jpeg"
	"testing"
)

func TestFitJPEGCapsEdge(t *testing.T) {
	img := image.NewRGBA(image.Rect(0, 0, 1000, 10))
	for y := 0; y < 10; y++ {
		for x := 0; x < 1000; x++ {
			img.Set(x, y, color.RGBA{10, 20, 30, 255})
		}
	}
	var body bytes.Buffer
	if err := jpeg.Encode(&body, img, &jpeg.Options{Quality: 90}); err != nil {
		t.Fatal(err)
	}
	out, err := FitJPEG(body.Bytes(), 512, 75)
	if err != nil {
		t.Fatal(err)
	}
	decoded, err := jpeg.Decode(bytes.NewReader(out))
	if err != nil {
		t.Fatalf("decode out: %v", err)
	}
	b := decoded.Bounds()
	w, h := b.Dx(), b.Dy()
	long := w
	if h > long {
		long = h
	}
	if long > 512 {
		t.Fatalf("long edge %d", long)
	}
}
