package service

import (
	"context"
	"testing"

	"investigate_bff/internal/domain"
)

func TestCustomersServiceListAppliesPaginationAndEnrichment(t *testing.T) {
	service := NewCustomersService(
		&mockCustomerDirectory{
			listCustomers: func(_ context.Context, filter domain.CustomerFilter) ([]domain.Customer, error) {
				if filter.Search != "customer" {
					t.Fatalf("expected normalized search, got %q", filter.Search)
				}
				return []domain.Customer{
					buildCustomer("c1"),
					buildCustomer("c2"),
				}, nil
			},
		},
		&mockAddressDirectory{
			getByCustomerIDs: func(_ context.Context, ids []string) (map[string][]domain.Address, error) {
				return map[string][]domain.Address{
					"c1": {{ID: "addr1", CustomerID: "c1", City: "Baku"}},
				}, nil
			},
		},
		&mockAccountDirectory{
			getByCustomerIDs: func(_ context.Context, ids []string) (map[string][]domain.BankAccount, error) {
				return map[string][]domain.BankAccount{
					"c1": {buildBankAccount("a1", "c1")},
				}, nil
			},
		},
		&mockTransactionDirectory{
			getByAccountIDs: func(_ context.Context, ids []string) (map[string][]domain.Transaction, error) {
				if len(ids) != 1 || ids[0] != "a1" {
					t.Fatalf("expected account a1, got %#v", ids)
				}
				return map[string][]domain.Transaction{
					"a1": {{ID: "t1", AccountID: "a1", Amount: 15}},
				}, nil
			},
		},
		&mockContactDirectory{
			getByCustomerIDs: func(_ context.Context, ids []string) (map[string][]domain.Contact, error) {
				return map[string][]domain.Contact{
					"c1": {{ID: "con1", CustomerID: "c1", Phone: "+994"}},
				}, nil
			},
		},
	)

	result, err := service.List(context.Background(), domain.ListCustomersCommand{
		Filter: domain.CustomerFilter{Search: " Customer "},
		Limit:  1,
		Includes: map[string]bool{
			"addresses":     true,
			"bank_accounts": true,
			"transactions":  true,
			"contacts":      true,
		},
	})
	if err != nil {
		t.Fatalf("List returned error: %v", err)
	}

	if len(result.Items) != 1 {
		t.Fatalf("expected 1 customer, got %d", len(result.Items))
	}
	if !result.HasMore || !result.PageInfo.HasMore {
		t.Fatalf("expected has_more to be true")
	}
	if len(result.Items[0].Addresses) != 1 {
		t.Fatalf("expected addresses enrichment")
	}
	if len(result.Items[0].BankAccounts) != 1 {
		t.Fatalf("expected bank accounts enrichment")
	}
	if len(result.Items[0].BankAccounts[0].Transactions) != 1 {
		t.Fatalf("expected transactions enrichment")
	}
	if len(result.Items[0].Contacts) != 1 {
		t.Fatalf("expected contacts enrichment")
	}
}
