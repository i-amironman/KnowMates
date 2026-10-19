package http

import (
	"net/http"
	"os"
)

type Server struct {
	mux *http.ServeMux
	dsn string
}

func NewServer(store any) *Server {
	_ = store
	s := &Server{
		mux: http.NewServeMux(),
		dsn: os.Getenv("DATABASE_URL"),
	}
	s.mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	return s
}

func (s *Server) Handler() http.Handler {
	return s.mux
}
