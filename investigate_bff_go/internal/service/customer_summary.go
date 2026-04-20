package service

import (
	"context"

	"investigate_bff/internal/domain"
)

type CustomerSummaryService struct {
	customers    customerDirectory
	addresses    addressDirectory
	accounts     accountDirectory
	transactions transactionDirectory
	contacts     contactDirectory
}

func NewCustomerSummaryService(
	customers customerDirectory,
	addresses addressDirectory,
	accounts accountDirectory,
	transactions transactionDirectory,
	contacts contactDirectory,
) *CustomerSummaryService {
	return &CustomerSummaryService{
		customers:    customers,
		addresses:    addresses,
		accounts:     accounts,
		transactions: transactions,
		contacts:     contacts,
	}
}

func (s *CustomerSummaryService) Get(ctx context.Context, cmd domain.GetCustomerSummaryCommand) (domain.CustomerSummary, error) {
	cmd.Normalize()
	if cmd.CustomerID == "" {
		return domain.CustomerSummary{}, domain.NewValidationError(domain.ValidationDetail{
			Field:  "customer_id",
			Reason: "REQUIRED",
		})
	}

	customerID := cmd.CustomerID
	customerIDs := []string{customerID}

	customersCh := async(func() ([]domain.Customer, error) {
		return s.customers.ListCustomers(ctx, domain.CustomerFilter{ID: customerID})
	})
	addressesCh := async(func() (map[string][]domain.Address, error) {
		return s.addresses.GetByCustomerIDs(ctx, customerIDs)
	})
	accountsCh := async(func() (map[string][]domain.BankAccount, error) {
		return s.accounts.GetByCustomerIDs(ctx, customerIDs)
	})
	contactsCh := async(func() (map[string][]domain.Contact, error) {
		return s.contacts.GetByCustomerIDs(ctx, customerIDs)
	})

	customersResult := <-customersCh
	if customersResult.err != nil {
		return domain.CustomerSummary{}, customersResult.err
	}
	if len(customersResult.value) == 0 {
		return domain.CustomerSummary{}, domain.ErrCustomerNotFound
	}

	addressesResult := <-addressesCh
	if addressesResult.err != nil {
		return domain.CustomerSummary{}, addressesResult.err
	}
	accountsResult := <-accountsCh
	if accountsResult.err != nil {
		return domain.CustomerSummary{}, accountsResult.err
	}
	contactsResult := <-contactsCh
	if contactsResult.err != nil {
		return domain.CustomerSummary{}, contactsResult.err
	}

	accounts := accountsResult.value[customerID]
	accountIDs := make([]string, len(accounts))
	for index := range accounts {
		accountIDs[index] = accounts[index].ID
	}

	transactions, err := s.transactions.GetByAccountIDs(ctx, accountIDs)
	if err != nil {
		return domain.CustomerSummary{}, err
	}

	return domain.BuildCustomerSummary(
		customersResult.value[0],
		addressesResult.value[customerID],
		accounts,
		transactions,
		contactsResult.value[customerID],
	), nil
}
