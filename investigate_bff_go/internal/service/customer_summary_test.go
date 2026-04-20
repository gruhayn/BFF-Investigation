package service

import (
	"context"
	"errors"
	"testing"

	"investigate_bff/internal/domain"
)

func TestCustomerSummaryServiceGetValidatesCustomerID(t *testing.T) {
	service := NewCustomerSummaryService(
		&mockCustomerDirectory{listCustomers: func(_ context.Context, _ domain.CustomerFilter) ([]domain.Customer, error) { return nil, nil }},
		&mockAddressDirectory{getByCustomerIDs: func(_ context.Context, _ []string) (map[string][]domain.Address, error) { return nil, nil }},
		&mockAccountDirectory{getByCustomerIDs: func(_ context.Context, _ []string) (map[string][]domain.BankAccount, error) { return nil, nil }},
		&mockTransactionDirectory{getByAccountIDs: func(_ context.Context, _ []string) (map[string][]domain.Transaction, error) { return nil, nil }},
		&mockContactDirectory{getByCustomerIDs: func(_ context.Context, _ []string) (map[string][]domain.Contact, error) { return nil, nil }},
	)

	_, err := service.Get(context.Background(), domain.GetCustomerSummaryCommand{})
	if err == nil {
		t.Fatal("expected validation error")
	}
	if _, ok := domain.AsValidationError(err); !ok {
		t.Fatalf("expected validation error, got %v", err)
	}
}

func TestCustomerSummaryServiceGetReturnsNotFound(t *testing.T) {
	service := NewCustomerSummaryService(
		&mockCustomerDirectory{listCustomers: func(_ context.Context, _ domain.CustomerFilter) ([]domain.Customer, error) {
			return []domain.Customer{}, nil
		}},
		&mockAddressDirectory{getByCustomerIDs: func(_ context.Context, _ []string) (map[string][]domain.Address, error) {
			return map[string][]domain.Address{}, nil
		}},
		&mockAccountDirectory{getByCustomerIDs: func(_ context.Context, _ []string) (map[string][]domain.BankAccount, error) {
			return map[string][]domain.BankAccount{}, nil
		}},
		&mockTransactionDirectory{getByAccountIDs: func(_ context.Context, _ []string) (map[string][]domain.Transaction, error) {
			return map[string][]domain.Transaction{}, nil
		}},
		&mockContactDirectory{getByCustomerIDs: func(_ context.Context, _ []string) (map[string][]domain.Contact, error) {
			return map[string][]domain.Contact{}, nil
		}},
	)

	_, err := service.Get(context.Background(), domain.GetCustomerSummaryCommand{CustomerID: "c1"})
	if !errors.Is(err, domain.ErrCustomerNotFound) {
		t.Fatalf("expected ErrCustomerNotFound, got %v", err)
	}
}

func TestCustomerSummaryServiceGetBuildsSummary(t *testing.T) {
	service := NewCustomerSummaryService(
		&mockCustomerDirectory{
			listCustomers: func(_ context.Context, filter domain.CustomerFilter) ([]domain.Customer, error) {
				if filter.ID != "c1" {
					t.Fatalf("expected customer filter c1, got %q", filter.ID)
				}
				return []domain.Customer{{ID: "c1", Name: "Jane", Email: "jane@example.com"}}, nil
			},
		},
		&mockAddressDirectory{
			getByCustomerIDs: func(_ context.Context, _ []string) (map[string][]domain.Address, error) {
				return map[string][]domain.Address{
					"c1": {{ID: "addr1", CustomerID: "c1"}},
				}, nil
			},
		},
		&mockAccountDirectory{
			getByCustomerIDs: func(_ context.Context, _ []string) (map[string][]domain.BankAccount, error) {
				return map[string][]domain.BankAccount{
					"c1": {
						{ID: "a1", CustomerID: "c1", AccountNumber: "ACC-1", Balance: 50},
						{ID: "a2", CustomerID: "c1", AccountNumber: "ACC-2", Balance: 75},
					},
				}, nil
			},
		},
		&mockTransactionDirectory{
			getByAccountIDs: func(_ context.Context, ids []string) (map[string][]domain.Transaction, error) {
				if len(ids) != 2 {
					t.Fatalf("expected two account ids, got %#v", ids)
				}
				return map[string][]domain.Transaction{
					"a1": {{ID: "t1", AccountID: "a1", Date: "2026-03-12"}},
					"a2": {{ID: "t2", AccountID: "a2", Date: "2026-03-10"}},
				}, nil
			},
		},
		&mockContactDirectory{
			getByCustomerIDs: func(_ context.Context, _ []string) (map[string][]domain.Contact, error) {
				return map[string][]domain.Contact{
					"c1": {{ID: "con1", CustomerID: "c1"}},
				}, nil
			},
		},
	)

	result, err := service.Get(context.Background(), domain.GetCustomerSummaryCommand{CustomerID: "c1"})
	if err != nil {
		t.Fatalf("Get returned error: %v", err)
	}

	if result.TotalBalance != 125 {
		t.Fatalf("expected total balance 125, got %v", result.TotalBalance)
	}
	if result.AccountCount != 2 {
		t.Fatalf("expected account count 2, got %d", result.AccountCount)
	}
	if result.TransactionCount != 2 {
		t.Fatalf("expected transaction count 2, got %d", result.TransactionCount)
	}
	if len(result.RecentActivity) != 2 {
		t.Fatalf("expected recent activity rows")
	}
	if result.RecentActivity[0].TransactionID != "t1" {
		t.Fatalf("expected most recent transaction first, got %q", result.RecentActivity[0].TransactionID)
	}
}
