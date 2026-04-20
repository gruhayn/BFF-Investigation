package client

import (
	"context"

	"investigate_bff/internal/domain"
)

type CustomerClient struct {
	store *store
}

func (c *CustomerClient) ListCustomers(_ context.Context, filter domain.CustomerFilter) ([]domain.Customer, error) {
	matched := make([]domain.Customer, 0)
	for _, customer := range c.store.customers {
		if matchesCustomerFilter(customer, filter) {
			matched = append(matched, customer)
		}
	}

	return copyCustomers(matched), nil
}
