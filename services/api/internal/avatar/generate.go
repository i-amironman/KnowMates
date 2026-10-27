package avatar

import (
	"bytes"
	"encoding/binary"
	"image"
	"image/color"
	"image/jpeg"
	"math"
	"math/rand"

	"github.com/google/uuid"
)

// GeneratePortraitJPEG builds a deterministic portrait-style avatar for the default pool (no external API).
// gender is "male" or "female" and shifts palette / hair placement.
func GeneratePortraitJPEG(seedID uuid.UUID, gender string) ([]byte, error) {
	const size = 512
	img := image.NewRGBA(image.Rect(0, 0, size, size))
	seed := binary.LittleEndian.Uint64(seedID[:8])
	rng := rand.New(rand.NewSource(int64(seed))) //nolint:gosec // visual seed only

	h1 := float64(rng.Intn(360))
	if gender == "female" {
		h1 = math.Mod(h1+180, 360)
	}
	h2 := math.Mod(h1+40+float64(rng.Intn(80)), 360)
	for y := 0; y < size; y++ {
		for x := 0; x < size; x++ {
			t := float64(y) / float64(size)
			img.Set(x, y, lerpHSL(h1, 0.55, 0.45, h2, 0.35, 0.25, t))
		}
	}

	cx, cy := size/2, size/2+20
	faceR := size / 3
	skinL := 0.78 + float64(rng.Intn(10))/100
	if gender == "male" {
		skinL -= 0.06
	}
	drawDisk(img, cx, cy, faceR, hsl(30, 0.25, skinL))

	eyeY := cy - faceR/3
	eyeDX := faceR / 2
	eyeR := faceR / 8
	drawDisk(img, cx-eyeDX, eyeY, eyeR, color.RGBA{30, 30, 40, 255})
	drawDisk(img, cx+eyeDX, eyeY, eyeR, color.RGBA{30, 30, 40, 255})
	drawDisk(img, cx-eyeDX+eyeR/4, eyeY-eyeR/4, eyeR/3, color.RGBA{255, 255, 255, 180})
	drawDisk(img, cx+eyeDX+eyeR/4, eyeY-eyeR/4, eyeR/3, color.RGBA{255, 255, 255, 180})

	mouthY := cy + faceR/3
	drawArcSmile(img, cx, mouthY, faceR/2, color.RGBA{180, 60, 90, 255})

	hairN := 6
	if gender == "female" {
		hairN = 8
	}
	for i := 0; i < hairN; i++ {
		angle := float64(i) * 2 * math.Pi / float64(hairN)
		hx := cx + int(float64(faceR+30)*math.Cos(angle))
		hy := cy - faceR/2 + int(float64(faceR/2)*math.Sin(angle))
		if gender == "female" {
			hy -= faceR / 4
		}
		drawDisk(img, hx, hy, faceR/3+rng.Intn(20), hsl(h1, 0.6, 0.35+float64(rng.Intn(15))/100))
	}

	var out bytes.Buffer
	if err := jpeg.Encode(&out, img, &jpeg.Options{Quality: 88}); err != nil {
		return nil, err
	}
	return out.Bytes(), nil
}

func drawDisk(img *image.RGBA, cx, cy, r int, c color.Color) {
	for y := cy - r; y <= cy+r; y++ {
		for x := cx - r; x <= cx+r; x++ {
			if x < 0 || y < 0 || x >= img.Bounds().Dx() || y >= img.Bounds().Dy() {
				continue
			}
			dx, dy := float64(x-cx), float64(y-cy)
			if dx*dx+dy*dy <= float64(r*r) {
				img.Set(x, y, c)
			}
		}
	}
}

func drawArcSmile(img *image.RGBA, cx, cy, w int, c color.Color) {
	for x := cx - w; x <= cx+w; x++ {
		if x < 0 || x >= img.Bounds().Dx() {
			continue
		}
		t := float64(x-cx) / float64(w)
		y := cy + int(0.15*float64(w)*t*t)
		if y >= 0 && y < img.Bounds().Dy() {
			img.Set(x, y, c)
			if y+1 < img.Bounds().Dy() {
				img.Set(x, y+1, c)
			}
		}
	}
}

func hsl(h, s, l float64) color.RGBA {
	h = math.Mod(h, 360)
	c := (1 - math.Abs(2*l-1)) * s
	x := c * (1 - math.Abs(math.Mod(h/60, 2)-1))
	m := l - c/2
	var r, g, b float64
	switch {
	case h < 60:
		r, g, b = c, x, 0
	case h < 120:
		r, g, b = x, c, 0
	case h < 180:
		r, g, b = 0, c, x
	case h < 240:
		r, g, b = 0, x, c
	case h < 300:
		r, g, b = x, 0, c
	default:
		r, g, b = c, 0, x
	}
	return color.RGBA{
		R: uint8((r + m) * 255),
		G: uint8((g + m) * 255),
		B: uint8((b + m) * 255),
		A: 255,
	}
}

func lerpHSL(h1, s1, l1, h2, s2, l2, t float64) color.RGBA {
	return hsl(h1+(h2-h1)*t, s1+(s2-s1)*t, l1+(l2-l1)*t)
}
