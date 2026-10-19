package http

import (
	"net/http"
	"os"
)

type Server struct {
	mux *http.ServeMux
	dsn   string
	users Users
}

func NewServer(users Users) *Server {
	s := &Server{
		mux:   http.NewServeMux(),
		dsn:   os.Getenv("DATABASE_URL"),
		users: users,
	}
	s.mux.HandleFunc("POST /v1/auth/signup", s.signUp)
	s.mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	return s
}

func (s *Server) Handler() http.Handler {
	return s.mux
}
