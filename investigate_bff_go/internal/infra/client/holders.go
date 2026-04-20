package client

import (
	"context"

	"investigate_bff/internal/domain"
)

type HolderClient struct {
	store *store
}

func (c *HolderClient) GetByAccountIDs(_ context.Context, ids []string) (map[string]domain.AccountHolder, error) {
	grouped := make(map[string]domain.AccountHolder, len(ids))
	for _, id := range ids {
		customerID := c.store.accountToCustomerID[id]
		if holder, ok := c.store.holderByCustomerID[customerID]; ok {
			grouped[id] = holder
		}
	}
	return grouped, nil
}
