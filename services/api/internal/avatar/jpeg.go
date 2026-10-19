package avatar

import (
	"bytes"
	"image"
	"image/jpeg"
)

func FitJPEG(body []byte, maxEdge int, quality int) ([]byte, error) {
	img, err := jpeg.Decode(bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	b := img.Bounds()
	w, h := b.Dx(), b.Dy()
	long := w
	if h > long {
		long = h
	}
	if long > maxEdge {
		nw := w * maxEdge / long
		nh := h * maxEdge / long
		if nw < 1 {
			nw = 1
		}
		if nh < 1 {
			nh = 1
		}
		dst := image.NewRGBA(image.Rect(0, 0, nw, nh))
		for y := 0; y < nh; y++ {
			for x := 0; x < nw; x++ {
				sx := b.Min.X + x*w/nw
				sy := b.Min.Y + y*h/nh
				dst.Set(x, y, img.At(sx, sy))
			}
		}
		img = dst
	}
	var out bytes.Buffer
	if err := jpeg.Encode(&out, img, &jpeg.Options{Quality: quality}); err != nil {
		return nil, err
	}
	return out.Bytes(), nil
}
