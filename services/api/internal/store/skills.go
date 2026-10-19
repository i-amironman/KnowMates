package store

import (
	"context"

	"github.com/google/uuid"
)

type CatalogSkill struct {
	ID   uuid.UUID `json:"id"`
	Slug string    `json:"slug"`
	Name string    `json:"name"`
}

func (s *Store) ListSkills(ctx context.Context, q string) ([]CatalogSkill, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, slug, name FROM skills
		WHERE ($1 = '' OR name ILIKE '%' || $1 || '%' OR slug ILIKE '%' || $1 || '%')
		ORDER BY name`, q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []CatalogSkill
	for rows.Next() {
		var sk CatalogSkill
		if err := rows.Scan(&sk.ID, &sk.Slug, &sk.Name); err != nil {
			return nil, err
		}
		out = append(out, sk)
	}
	return out, rows.Err()
}
