package mail

import (
	"context"
	"crypto/tls"
	"fmt"
	"log"
	"net"
	"net/smtp"
	"os"
)

// Sender delivers plain-text email.
type Sender interface {
	Send(ctx context.Context, to, subject, text string) error
}

// LogSender prints mail to the log (dev / empty SMTP_HOST).
type LogSender struct{}

func (LogSender) Send(_ context.Context, to, subject, text string) error {
	log.Printf("mail: to=%s subject=%q\n%s", to, subject, text)
	return nil
}

// SMTPSender sends via STARTTLS on SMTP_PORT (default 587).
type SMTPSender struct {
	Host, Port, User, Password, From string
}

func (s *SMTPSender) Send(_ context.Context, to, subject, text string) error {
	port := s.Port
	if port == "" {
		port = "587"
	}
	addr := net.JoinHostPort(s.Host, port)
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		return err
	}
	defer conn.Close()
	client, err := smtp.NewClient(conn, s.Host)
	if err != nil {
		return err
	}
	defer client.Close()
	if err := client.StartTLS(&tls.Config{ServerName: s.Host}); err != nil {
		return err
	}
	if s.User != "" {
		if err := client.Auth(smtp.PlainAuth("", s.User, s.Password, s.Host)); err != nil {
			return err
		}
	}
	if err := client.Mail(s.From); err != nil {
		return err
	}
	if err := client.Rcpt(to); err != nil {
		return err
	}
	w, err := client.Data()
	if err != nil {
		return err
	}
	_, err = fmt.Fprintf(w, "From: KnowMates <%s>\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n%s", s.From, to, subject, text)
	if err != nil {
		return err
	}
	if err := w.Close(); err != nil {
		return err
	}
	return client.Quit()
}

// SenderFromEnv returns LogSender when SMTP_HOST is empty.
func SenderFromEnv() Sender {
	host := os.Getenv("SMTP_HOST")
	if host == "" {
		return LogSender{}
	}
	port := os.Getenv("SMTP_PORT")
	if port == "" {
		port = "587"
	}
	return &SMTPSender{
		Host:     host,
		Port:     port,
		User:     os.Getenv("SMTP_USER"),
		Password: os.Getenv("SMTP_PASSWORD"),
		From:     os.Getenv("SMTP_FROM"),
	}
}
