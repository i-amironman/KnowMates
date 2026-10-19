package http

import (
	"net/http"
	"os"

	"knowmates/services/api/internal/avatar"
)

// Deps wires store-backed auth into the HTTP server.
type Deps struct {
	Users    Users
	SignIn   SignInUsers
	Sessions Sessions
	Profiles ProfileStore
	Avatars  avatar.AvatarStore
	Secret   []byte
	Redis    RedisClient
}

type Server struct {
	mux        *http.ServeMux
	dsn        string
	users      Users
	creds      SignInUsers
	sessions   Sessions
	profiles   ProfileStore
	avatars    avatar.AvatarStore
	authSecret []byte
	redis      RedisClient
}

func NewServer(d Deps) *Server {
	s := &Server{
		mux:        http.NewServeMux(),
		dsn:        os.Getenv("DATABASE_URL"),
		users:      d.Users,
		creds:      d.SignIn,
		sessions:   d.Sessions,
		profiles:   d.Profiles,
		avatars:    d.Avatars,
		authSecret: d.Secret,
		redis:      d.Redis,
	}
	s.mux.HandleFunc("POST /v1/auth/sign-up", s.signUp)
	s.mux.HandleFunc("POST /v1/auth/sign-in", s.signIn)
	s.mux.HandleFunc("POST /v1/auth/refresh", s.refresh)
	s.mux.HandleFunc("POST /v1/auth/sign-out", s.WithUser(s.signOut))
	s.mux.HandleFunc("GET /v1/me", s.WithUser(s.getMe))
	s.mux.HandleFunc("PATCH /v1/me", s.WithUser(s.patchMe))
	s.mux.HandleFunc("PUT /v1/me/skills", s.WithUser(s.putSkills))
	s.mux.HandleFunc("PUT /v1/me/availability", s.WithUser(s.putAvailability))
	s.mux.HandleFunc("POST /v1/me/avatar", s.WithUser(s.postAvatar))
	s.mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	return s
}

func (s *Server) Handler() http.Handler {
	return s.mux
}
