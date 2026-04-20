package client

import (
	"context"

	"investigate_bff/internal/domain"
)

type AccountClient struct {
	store *store
}

func (c *AccountClient) ListAccountDetails(_ context.Context, filter domain.AccountDetailFilter) ([]domain.AccountDetail, error) {
	matched := make([]domain.AccountDetail, 0)
	for _, account := range c.store.accountDetails {
		if matchesAccountFilter(account, filter) {
			matched = append(matched, account)
		}
	}

	return copyAccountDetails(matched), nil
}

func (c *AccountClient) GetByCustomerIDs(_ context.Context, ids []string) (map[string][]domain.BankAccount, error) {
	grouped := make(map[string][]domain.BankAccount, len(ids))
	for _, id := range ids {
		grouped[id] = copyBankAccounts(c.store.accountsByCustomerID[id])
	}
	return grouped, nil
}
