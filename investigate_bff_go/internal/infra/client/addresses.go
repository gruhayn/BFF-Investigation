package client

import (
	"context"

	"investigate_bff/internal/domain"
)

type AddressClient struct {
	store *store
}

func (c *AddressClient) GetByCustomerIDs(_ context.Context, ids []string) (map[string][]domain.Address, error) {
	grouped := make(map[string][]domain.Address, len(ids))
	for _, id := range ids {
		grouped[id] = copyAddresses(c.store.addressesByCustomerID[id])
	}
	return grouped, nil
}
