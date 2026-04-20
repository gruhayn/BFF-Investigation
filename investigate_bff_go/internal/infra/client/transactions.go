package client

import (
	"context"

	"investigate_bff/internal/domain"
)

type TransactionClient struct {
	store *store
}

func (c *TransactionClient) GetByAccountIDs(_ context.Context, ids []string) (map[string][]domain.Transaction, error) {
	grouped := make(map[string][]domain.Transaction, len(ids))
	for _, id := range ids {
		grouped[id] = copyTransactions(c.store.transactionsByAccount[id])
	}
	return grouped, nil
}
