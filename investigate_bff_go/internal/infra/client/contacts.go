package client

import (
	"context"

	"investigate_bff/internal/domain"
)

type ContactClient struct {
	store *store
}

func (c *ContactClient) GetByCustomerIDs(_ context.Context, ids []string) (map[string][]domain.Contact, error) {
	grouped := make(map[string][]domain.Contact, len(ids))
	for _, id := range ids {
		grouped[id] = copyContacts(c.store.contactsByCustomerID[id])
	}
	return grouped, nil
}
