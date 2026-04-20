package service

import (
	"context"

	"investigate_bff/internal/domain"
)

type customerDirectory interface {
	ListCustomers(ctx context.Context, filter domain.CustomerFilter) ([]domain.Customer, error)
}

type accountDirectory interface {
	ListAccountDetails(ctx context.Context, filter domain.AccountDetailFilter) ([]domain.AccountDetail, error)
	GetByCustomerIDs(ctx context.Context, ids []string) (map[string][]domain.BankAccount, error)
}

type addressDirectory interface {
	GetByCustomerIDs(ctx context.Context, ids []string) (map[string][]domain.Address, error)
}

type transactionDirectory interface {
	GetByAccountIDs(ctx context.Context, ids []string) (map[string][]domain.Transaction, error)
}

type contactDirectory interface {
	GetByCustomerIDs(ctx context.Context, ids []string) (map[string][]domain.Contact, error)
}

type holderDirectory interface {
	GetByAccountIDs(ctx context.Context, ids []string) (map[string]domain.AccountHolder, error)
}
