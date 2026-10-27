package store

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type ChatThreadView struct {
	ID              uuid.UUID  `json:"id"`
	RequestID       uuid.UUID  `json:"requestId"`
	CounterpartID   uuid.UUID  `json:"counterpartId"`
	CounterpartName string     `json:"counterpartName"`
	SkillName       string     `json:"skillName"`
	MyPublicKey     string     `json:"myPublicKey,omitempty"`
	TheirPublicKey  string     `json:"theirPublicKey,omitempty"`
}

type ChatMessageRow struct {
	ID         uuid.UUID `json:"id"`
	SenderID   uuid.UUID `json:"senderId"`
	Ciphertext string    `json:"ciphertext"`
	Nonce      string    `json:"nonce"`
	CreatedAt  string    `json:"createdAt"`
}

func (s *Store) OpenChatForRequest(ctx context.Context, requestID uuid.UUID) (uuid.UUID, error) {
	var threadID uuid.UUID
	err := s.pool.QueryRow(ctx, `
		INSERT INTO chat_threads (id, request_id, learner_id, teacher_id)
		SELECT gen_random_uuid(), r.id, r.learner_id, r.teacher_id
		FROM swap_requests r
		WHERE r.id = $1 AND r.status = 'accepted'
		ON CONFLICT (request_id) DO NOTHING
		RETURNING id`, requestID).Scan(&threadID)
	if errors.Is(err, pgx.ErrNoRows) {
		err = s.pool.QueryRow(ctx, `SELECT id FROM chat_threads WHERE request_id = $1`, requestID).Scan(&threadID)
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return uuid.Nil, ErrNoSuchRequest
	}
	return threadID, err
}

func (s *Store) ChatThreadIDForRequest(ctx context.Context, requestID uuid.UUID) (uuid.UUID, error) {
	var id uuid.UUID
	err := s.pool.QueryRow(ctx, `SELECT id FROM chat_threads WHERE request_id = $1`, requestID).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return uuid.Nil, ErrNoSuchRequest
	}
	return id, err
}

func (s *Store) UpsertChatPublicKey(ctx context.Context, threadID, userID uuid.UUID, publicKey string) error {
	if publicKey == "" {
		return ErrForbidden
	}
	var ok bool
	err := s.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM chat_threads
			WHERE id = $1 AND (learner_id = $2 OR teacher_id = $2)
		)`, threadID, userID).Scan(&ok)
	if err != nil {
		return err
	}
	if !ok {
		return ErrForbidden
	}
	_, err = s.pool.Exec(ctx, `
		INSERT INTO chat_participant_keys (thread_id, user_id, public_key, updated_at)
		VALUES ($1, $2, $3, now())
		ON CONFLICT (thread_id, user_id) DO UPDATE
		SET public_key = EXCLUDED.public_key, updated_at = now()`,
		threadID, userID, publicKey)
	return err
}

func (s *Store) ListChatThreads(ctx context.Context, userID uuid.UUID) ([]ChatThreadView, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT t.id, t.request_id,
			CASE WHEN t.learner_id = $1 THEN t.teacher_id ELSE t.learner_id END,
			CASE WHEN t.learner_id = $1 THEN ut.display_name ELSE ul.display_name END,
			sk.name,
			COALESCE(mk.public_key, ''),
			COALESCE(ok.public_key, '')
		FROM chat_threads t
		JOIN swap_requests r ON r.id = t.request_id
		JOIN skills sk ON sk.id = r.skill_id
		JOIN users ul ON ul.id = t.learner_id
		JOIN users ut ON ut.id = t.teacher_id
		LEFT JOIN chat_participant_keys mk ON mk.thread_id = t.id AND mk.user_id = $1
		LEFT JOIN chat_participant_keys ok ON ok.thread_id = t.id
			AND ok.user_id = CASE WHEN t.learner_id = $1 THEN t.teacher_id ELSE t.learner_id END
		WHERE t.learner_id = $1 OR t.teacher_id = $1
		ORDER BY t.created_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []ChatThreadView
	for rows.Next() {
		var v ChatThreadView
		if err := rows.Scan(&v.ID, &v.RequestID, &v.CounterpartID, &v.CounterpartName,
			&v.SkillName, &v.MyPublicKey, &v.TheirPublicKey); err != nil {
			return nil, err
		}
		out = append(out, v)
	}
	return out, rows.Err()
}

func (s *Store) GetChatThread(ctx context.Context, threadID, userID uuid.UUID) (ChatThreadView, error) {
	var v ChatThreadView
	err := s.pool.QueryRow(ctx, `
		SELECT t.id, t.request_id,
			CASE WHEN t.learner_id = $2 THEN t.teacher_id ELSE t.learner_id END,
			CASE WHEN t.learner_id = $2 THEN ut.display_name ELSE ul.display_name END,
			sk.name,
			COALESCE(mk.public_key, ''),
			COALESCE(ok.public_key, '')
		FROM chat_threads t
		JOIN swap_requests r ON r.id = t.request_id
		JOIN skills sk ON sk.id = r.skill_id
		JOIN users ul ON ul.id = t.learner_id
		JOIN users ut ON ut.id = t.teacher_id
		LEFT JOIN chat_participant_keys mk ON mk.thread_id = t.id AND mk.user_id = $2
		LEFT JOIN chat_participant_keys ok ON ok.thread_id = t.id
			AND ok.user_id = CASE WHEN t.learner_id = $2 THEN t.teacher_id ELSE t.learner_id END
		WHERE t.id = $1 AND (t.learner_id = $2 OR t.teacher_id = $2)`,
		threadID, userID).Scan(&v.ID, &v.RequestID, &v.CounterpartID, &v.CounterpartName,
		&v.SkillName, &v.MyPublicKey, &v.TheirPublicKey)
	if errors.Is(err, pgx.ErrNoRows) {
		return ChatThreadView{}, ErrNoSuchRequest
	}
	return v, err
}

func (s *Store) InsertChatMessage(ctx context.Context, threadID, sender uuid.UUID, ciphertext, nonce string) (ChatMessageRow, error) {
	if ciphertext == "" || nonce == "" {
		return ChatMessageRow{}, ErrForbidden
	}
	var ok bool
	err := s.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM chat_threads
			WHERE id = $1 AND (learner_id = $2 OR teacher_id = $2)
		)`, threadID, sender).Scan(&ok)
	if err != nil {
		return ChatMessageRow{}, err
	}
	if !ok {
		return ChatMessageRow{}, ErrForbidden
	}
	var row ChatMessageRow
	err = s.pool.QueryRow(ctx, `
		INSERT INTO chat_messages (thread_id, sender_id, ciphertext, nonce)
		VALUES ($1, $2, $3, $4)
		RETURNING id, sender_id, ciphertext, nonce, created_at::text`,
		threadID, sender, ciphertext, nonce).
		Scan(&row.ID, &row.SenderID, &row.Ciphertext, &row.Nonce, &row.CreatedAt)
	return row, err
}

func (s *Store) ListChatMessages(ctx context.Context, threadID, userID uuid.UUID, afterID *uuid.UUID) ([]ChatMessageRow, error) {
	if _, err := s.GetChatThread(ctx, threadID, userID); err != nil {
		return nil, err
	}
	var rows pgx.Rows
	var err error
	if afterID != nil && *afterID != uuid.Nil {
		rows, err = s.pool.Query(ctx, `
			SELECT id, sender_id, ciphertext, nonce, created_at::text
			FROM chat_messages
			WHERE thread_id = $1 AND created_at > (
				SELECT created_at FROM chat_messages WHERE id = $2
			)
			ORDER BY created_at ASC`, threadID, *afterID)
	} else {
		rows, err = s.pool.Query(ctx, `
			SELECT id, sender_id, ciphertext, nonce, created_at::text
			FROM chat_messages
			WHERE thread_id = $1
			ORDER BY created_at ASC
			LIMIT 200`, threadID)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []ChatMessageRow
	for rows.Next() {
		var row ChatMessageRow
		if err := rows.Scan(&row.ID, &row.SenderID, &row.Ciphertext, &row.Nonce, &row.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

func (s *Store) ChatCounterpart(ctx context.Context, threadID, sender uuid.UUID) (uuid.UUID, error) {
	var learner, teacher uuid.UUID
	err := s.pool.QueryRow(ctx, `
		SELECT learner_id, teacher_id FROM chat_threads WHERE id = $1`, threadID).
		Scan(&learner, &teacher)
	if errors.Is(err, pgx.ErrNoRows) {
		return uuid.Nil, ErrNoSuchRequest
	}
	if err != nil {
		return uuid.Nil, err
	}
	if sender == learner {
		return teacher, nil
	}
	if sender == teacher {
		return learner, nil
	}
	return uuid.Nil, ErrForbidden
}
