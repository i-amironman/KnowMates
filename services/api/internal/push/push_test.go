package push

import (
	"context"
	"testing"
)

func TestLogPusherSend(t *testing.T) {
	var p LogPusher
	if err := p.Send(context.Background(), "tok", "t", "b"); err != nil {
		t.Fatal(err)
	}
}
