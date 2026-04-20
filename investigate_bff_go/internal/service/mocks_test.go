package service

import (
	"context"

	"investigate_bff/internal/domain"
)

type mockCustomerDirectory struct {
	listCustomers func(ctx context.Context, filter domain.CustomerFilter) ([]domain.Customer, error)
}

func (m *mockCustomerDirectory) ListCustomers(ctx context.Context, filter domain.CustomerFilter) ([]domain.Customer, error) {
	return m.listCustomers(ctx, filter)
}

type mockAccountDirectory struct {
	listAccountDetails func(ctx context.Context, filter domain.AccountDetailFilter) ([]domain.AccountDetail, error)
	getByCustomerIDs   func(ctx context.Context, ids []string) (map[string][]domain.BankAccount, error)
}

func (m *mockAccountDirectory) ListAccountDetails(ctx context.Context, filter domain.AccountDetailFilter) ([]domain.AccountDetail, error) {
	if m.listAccountDetails == nil {
		return nil, nil
	}
	return m.listAccountDetails(ctx, filter)
}

func (m *mockAccountDirectory) GetByCustomerIDs(ctx context.Context, ids []string) (map[string][]domain.BankAccount, error) {
	return m.getByCustomerIDs(ctx, ids)
}

type mockAddressDirectory struct {
	getByCustomerIDs func(ctx context.Context, ids []string) (map[string][]domain.Address, error)
}

func (m *mockAddressDirectory) GetByCustomerIDs(ctx context.Context, ids []string) (map[string][]domain.Address, error) {
	return m.getByCustomerIDs(ctx, ids)
}

type mockTransactionDirectory struct {
	getByAccountIDs func(ctx context.Context, ids []string) (map[string][]domain.Transaction, error)
}

func (m *mockTransactionDirectory) GetByAccountIDs(ctx context.Context, ids []string) (map[string][]domain.Transaction, error) {
	return m.getByAccountIDs(ctx, ids)
}

type mockContactDirectory struct {
	getByCustomerIDs func(ctx context.Context, ids []string) (map[string][]domain.Contact, error)
}

func (m *mockContactDirectory) GetByCustomerIDs(ctx context.Context, ids []string) (map[string][]domain.Contact, error) {
	return m.getByCustomerIDs(ctx, ids)
}

type mockHolderDirectory struct {
	getByAccountIDs func(ctx context.Context, ids []string) (map[string]domain.AccountHolder, error)
}

func (m *mockHolderDirectory) GetByAccountIDs(ctx context.Context, ids []string) (map[string]domain.AccountHolder, error) {
	return m.getByAccountIDs(ctx, ids)
}
