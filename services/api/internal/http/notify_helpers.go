package http

import (
	"context"
	"fmt"
	"log"

	"github.com/google/uuid"
)

func (s *Server) notifyUser(ctx context.Context, userID uuid.UUID, kind string, refID uuid.UUID, title, body string) {
	if s.notifications != nil {
		if err := s.notifications.InsertNotification(ctx, userID, kind, refID, title, body); err != nil {
			log.Printf("notify insert: %v", err)
		}
	}
	if s.push == nil || s.devices == nil {
		return
	}
	token, err := s.devices.LatestDeviceToken(ctx, userID)
	if err != nil || token == "" {
		return
	}
	if err := s.push.Send(ctx, token, title, body); err != nil {
		log.Printf("push: %v", err)
	}
}

func (s *Server) displayName(ctx context.Context, userID uuid.UUID) string {
	if s.notifications == nil {
		return "Someone"
	}
	name, err := s.notifications.DisplayName(ctx, userID)
	if err != nil || name == "" {
		return "Someone"
	}
	return name
}

func sessionRequestCopy(learnerName, skillName string) (string, string) {
	return "New session request", fmt.Sprintf("%s wants to learn %s with you.", learnerName, skillName)
}

func requestAcceptedCopy(teacherName, skillName string) (string, string) {
	return "Request accepted",
		fmt.Sprintf("%s accepted your %s session. Encrypted chat is ready.", teacherName, skillName)
}
