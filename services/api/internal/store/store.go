package store

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"sort"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"knowmates/services/api/migrations"
)

var (
	ErrEmailTaken      = errors.New("store: email already registered")
	ErrNoSuchUser      = errors.New("store: user not found")
	ErrNoSuchRefresh   = errors.New("store: refresh not found")
	ErrRefreshRevoked  = errors.New("store: refresh revoked reuse")
	ErrRefreshExpired  = errors.New("store: refresh expired")
	ErrForbidden       = errors.New("store: forbidden")
	ErrConflict        = errors.New("store: conflict")
	ErrNoSuchRequest         = errors.New("store: request not found")
	ErrNoSuchSession         = errors.New("store: session not found")
	ErrInsufficientCredits   = errors.New("store: insufficient credits")
	ErrBadMeetingURL         = errors.New("store: bad meeting url")
)

type Store struct {
	pool     *pgxpool.Pool
	readPool *pgxpool.Pool
}

type User struct {
	ID        string    `json:"id"`
	Email     string    `json:"email"`
	BirthDate time.Time `json:"-"`
	Timezone  string    `json:"timezone"`
	CreatedAt time.Time `json:"created_at"`
}

func Open(ctx context.Context, dsn string) (*Store, error) {
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		return nil, err
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, err
	}
	return &Store{pool: pool}, nil
}

func (s *Store) Close() {
	if s.readPool != nil && s.readPool != s.pool {
		s.readPool.Close()
	}
	s.pool.Close()
}

func (s *Store) readQ() *pgxpool.Pool {
	if s.readPool != nil {
		return s.readPool
	}
	return s.pool
}

// AttachReadPool opens an optional read replica for discovery queries.
func (s *Store) AttachReadPool(ctx context.Context, dsn string) error {
	if dsn == "" {
		return nil
	}
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		return err
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return err
	}
	s.readPool = pool
	return nil
}

// Migrate applies migrations/*.sql in name order, recording each filename once.
// ponytail: a Postgres advisory lock serializes concurrent API instances; no down-migrations.
func (s *Store) Migrate(ctx context.Context) error {
	conn, err := s.pool.Acquire(ctx)
	if err != nil {
		return err
	}
	defer conn.Release()
	if _, err := conn.Exec(ctx, `SELECT pg_advisory_lock(7461001)`); err != nil {
		return err
	}
	defer conn.Exec(context.Background(), `SELECT pg_advisory_unlock(7461001)`) //nolint:errcheck
	if _, err := conn.Exec(ctx, `CREATE TABLE IF NOT EXISTS schema_migrations (filename text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())`); err != nil {
		return err
	}
	files, err := fs.Glob(migrations.FS, "*.sql")
	if err != nil {
		return err
	}
	sort.Strings(files)
	for _, f := range files {
		var done bool
		if err := conn.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM schema_migrations WHERE filename = $1)`, f).Scan(&done); err != nil {
			return err
		}
		if done {
			continue
		}
		sql, err := fs.ReadFile(migrations.FS, f)
		if err != nil {
			return err
		}
		tx, err := conn.Begin(ctx)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, string(sql)); err != nil {
			_ = tx.Rollback(ctx)
			return fmt.Errorf("migration %s: %w", f, err)
		}
		if _, err := tx.Exec(ctx, `INSERT INTO schema_migrations (filename) VALUES ($1)`, f); err != nil {
			_ = tx.Rollback(ctx)
			return err
		}
		if err := tx.Commit(ctx); err != nil {
			return err
		}
	}
	return nil
}

// AgeYears is the completed years between birth and today.
func AgeYears(birth, today time.Time) int {
	age := today.Year() - birth.Year()
	if today.Month() < birth.Month() || (today.Month() == birth.Month() && today.Day() < birth.Day()) {
		age--
	}
	return age
}

func (s *Store) CreateUser(ctx context.Context, email, hash string, birth time.Time, timezone string) (User, error) {
	u := User{BirthDate: birth}
	err := s.pool.QueryRow(ctx,
		`INSERT INTO users (id, email, password_hash, birth_date, timezone)
		 VALUES (gen_random_uuid(), $1, $2, $3, $4)
		 RETURNING id::text, email::text, timezone, created_at`,
		email, hash, birth, timezone).Scan(&u.ID, &u.Email, &u.Timezone, &u.CreatedAt)
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		return User{}, ErrEmailTaken
	}
	return u, err
}

func (s *Store) UserCredsByEmail(ctx context.Context, email string) (id, passwordHash string, err error) {
	err = s.pool.QueryRow(ctx,
		`SELECT id::text, password_hash FROM users WHERE email = $1`, email).
		Scan(&id, &passwordHash)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", "", ErrNoSuchUser
	}
	return id, passwordHash, err
}

const refreshTTL = 30 * 24 * time.Hour

func (s *Store) InsertRefresh(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at)
		 VALUES (gen_random_uuid(), $1, $2, $3)`,
		userID, tokenHash, expiresAt)
	return err
}

// RotateRefresh revokes the presented token and inserts a new one in one transaction.
// Reuse of an already-revoked token revokes every active refresh for that user.
func (s *Store) RotateRefresh(ctx context.Context, tokenHash, newHash string, newExpires time.Time) (userID string, err error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	var id, uid string
	var expiresAt time.Time
	var revokedAt *time.Time
	err = tx.QueryRow(ctx,
		`SELECT id::text, user_id::text, expires_at, revoked_at
		 FROM refresh_tokens WHERE token_hash = $1 FOR UPDATE`,
		tokenHash).Scan(&id, &uid, &expiresAt, &revokedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNoSuchRefresh
	}
	if err != nil {
		return "", err
	}
	if revokedAt != nil {
		if _, err := tx.Exec(ctx,
			`UPDATE refresh_tokens SET revoked_at = now()
			 WHERE user_id = $1 AND revoked_at IS NULL`, uid); err != nil {
			return "", err
		}
		if err := tx.Commit(ctx); err != nil {
			return "", err
		}
		return "", ErrRefreshRevoked
	}
	if time.Now().After(expiresAt) {
		return "", ErrRefreshExpired
	}
	if _, err := tx.Exec(ctx, `UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1`, id); err != nil {
		return "", err
	}
	if _, err := tx.Exec(ctx,
		`INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at)
		 VALUES (gen_random_uuid(), $1, $2, $3)`,
		uid, newHash, newExpires); err != nil {
		return "", err
	}
	if err := tx.Commit(ctx); err != nil {
		return "", err
	}
	return uid, nil
}

// RevokeRefresh sets revoked_at on the matching refresh row (sign-out).
type CallMessage struct {
	ID        uuid.UUID `json:"id"`
	From      uuid.UUID `json:"from"`
	Body      string    `json:"body"`
	CreatedAt time.Time `json:"createdAt"`
}

func (s *Store) InsertCallMessage(ctx context.Context, sessionID, sender uuid.UUID, body string) (uuid.UUID, time.Time, error) {
	var id uuid.UUID
	var created time.Time
	err := s.pool.QueryRow(ctx,
		`INSERT INTO session_messages (id, session_id, sender_id, body)
		 VALUES (gen_random_uuid(), $1, $2, $3)
		 RETURNING id, created_at`,
		sessionID, sender, body).Scan(&id, &created)
	return id, created, err
}

func (s *Store) CallHistory(ctx context.Context, sessionID uuid.UUID) ([]CallMessage, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, sender_id, body, created_at FROM (
			SELECT id, sender_id, body, created_at
			FROM session_messages WHERE session_id = $1
			ORDER BY created_at DESC LIMIT 100
		) sub ORDER BY created_at ASC`, sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []CallMessage
	for rows.Next() {
		var m CallMessage
		if err := rows.Scan(&m.ID, &m.From, &m.Body, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (s *Store) RevokeRefresh(ctx context.Context, userID, tokenHash string) error {
	tag, err := s.pool.Exec(ctx,
		`UPDATE refresh_tokens SET revoked_at = now()
		 WHERE token_hash = $1 AND user_id = $2 AND revoked_at IS NULL`,
		tokenHash, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNoSuchRefresh
	}
	return nil
}

