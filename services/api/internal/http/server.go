package http

import (
	"context"
	"net/http"
	"os"

	"knowmates/services/api/internal/avatar"
	"knowmates/services/api/internal/mail"
)

// Deps wires store-backed auth into the HTTP server.
type Deps struct {
	Users    Users
	SignIn   SignInUsers
	Sessions Sessions
	Profiles ProfileStore
	Skills   SkillsCatalog
	Discover DiscoverStore
	Requests RequestStore
	Bookings BookingStore
	Safety   SafetyStore
	Calls         CallStore
	Avatars       avatar.AvatarStore
	Secret        []byte
	Redis         RedisClient
	EmailVerified EmailVerifier
	VerifyTokens  VerifyTokens
	UserEmail     UserEmail
	Mail          mail.Sender
	PublicHost    string
	Devices       DeviceStore
	Push          pushPusher
}

type pushPusher interface {
	Send(ctx context.Context, token, title, body string) error
}

type Server struct {
	mux           *http.ServeMux
	dsn           string
	users         Users
	creds         SignInUsers
	sessions      Sessions
	profiles      ProfileStore
	skills        SkillsCatalog
	discover      DiscoverStore
	requests      RequestStore
	bookings      BookingStore
	safety        SafetyStore
	calls         CallStore
	avatars       avatar.AvatarStore
	authSecret    []byte
	redis         RedisClient
	discoverRedis DiscoverRedis
	emailVerified EmailVerifier
	verifyTokens  VerifyTokens
	userEmail     UserEmail
	mail          mail.Sender
	publicHost    string
	devices       DeviceStore
	push          pushPusher
}

func NewServer(d Deps) *Server {
	s := &Server{
		mux:        http.NewServeMux(),
		dsn:        os.Getenv("DATABASE_URL"),
		users:      d.Users,
		creds:      d.SignIn,
		sessions:   d.Sessions,
		profiles:   d.Profiles,
		skills:        d.Skills,
		discover:      d.Discover,
		requests:      d.Requests,
		bookings:      d.Bookings,
		safety:        d.Safety,
		calls:         d.Calls,
		avatars:       d.Avatars,
		authSecret:    d.Secret,
		redis:         d.Redis,
		discoverRedis: d.Redis,
		emailVerified: d.EmailVerified,
		verifyTokens:  d.VerifyTokens,
		userEmail:     d.UserEmail,
		mail:          d.Mail,
		publicHost:    d.PublicHost,
		devices:       d.Devices,
		push:          d.Push,
	}
	if s.publicHost == "" {
		s.publicHost = os.Getenv("PUBLIC_HOST")
	}
	if s.mail == nil {
		s.mail = mail.SenderFromEnv()
	}
	s.mux.HandleFunc("POST /v1/auth/sign-up", s.signUp)
	s.mux.HandleFunc("GET /v1/auth/verify", s.getVerify)
	s.mux.HandleFunc("POST /v1/auth/verify/resend", s.WithUser(s.postVerifyResend))
	s.mux.HandleFunc("POST /v1/auth/sign-in", s.signIn)
	s.mux.HandleFunc("POST /v1/auth/refresh", s.refresh)
	s.mux.HandleFunc("POST /v1/auth/sign-out", s.WithUser(s.signOut))
	s.mux.HandleFunc("GET /v1/me", s.WithUser(s.getMe))
	s.mux.HandleFunc("PATCH /v1/me", s.WithUser(s.patchMe))
	s.mux.HandleFunc("PUT /v1/me/skills", s.WithUser(s.putSkills))
	s.mux.HandleFunc("PUT /v1/me/availability", s.WithUser(s.putAvailability))
	s.mux.HandleFunc("GET /v1/skills", s.WithUser(s.getSkills))
	s.mux.HandleFunc("GET /v1/discover", s.WithUser(s.getDiscover))
	s.mux.HandleFunc("GET /v1/requests", s.WithUser(s.getRequests))
	s.mux.HandleFunc("POST /v1/requests", s.WithUser(s.postRequest))
	s.mux.HandleFunc("POST /v1/requests/{id}/accept", s.WithUser(s.acceptRequest))
	s.mux.HandleFunc("POST /v1/requests/{id}/decline", s.WithUser(s.declineRequest))
	s.mux.HandleFunc("POST /v1/requests/{id}/cancel", s.WithUser(s.cancelRequest))
	s.mux.HandleFunc("GET /v1/sessions", s.WithUser(s.getSessions))
	s.mux.HandleFunc("POST /v1/sessions", s.WithUser(s.postSession))
	s.mux.HandleFunc("POST /v1/sessions/{id}/complete", s.WithUser(s.completeSession))
	s.mux.HandleFunc("POST /v1/sessions/{id}/cancel", s.WithUser(s.cancelSession))
	s.mux.HandleFunc("POST /v1/sessions/{id}/reviews", s.WithUser(s.postSessionReview))
	s.mux.HandleFunc("POST /v1/sessions/{id}/call/ticket", s.WithUser(s.postCallTicket))
	s.mux.HandleFunc("GET /v1/sessions/{id}/call", s.WithUser(s.getCallWebSocket))
	s.mux.HandleFunc("GET /v1/wallet", s.WithUser(s.getWallet))
	s.mux.HandleFunc("POST /v1/me/avatar", s.WithUser(s.postAvatar))
	s.mux.HandleFunc("POST /v1/me/device", s.WithUser(s.postMeDevice))
	s.mux.HandleFunc("DELETE /v1/me", s.WithUser(s.deleteMe))
	s.mux.HandleFunc("POST /v1/blocks", s.WithUser(s.postBlock))
	s.mux.HandleFunc("DELETE /v1/blocks/{userId}", s.WithUser(s.deleteBlock))
	s.mux.HandleFunc("POST /v1/reports", s.WithUser(s.postReport))
	s.mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	return s
}

func (s *Server) Handler() http.Handler {
	return s.mux
}
